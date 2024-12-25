// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { IERC1155MetadataURIUpgradeable } from
    "@openzeppelin/contracts-upgradeable/interfaces/IERC1155MetadataURIUpgradeable.sol";
import { IERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC165Upgradeable.sol";
import { ICreator1155 } from "../interfaces/ICreator1155.sol";
import { ICreator1155Initializer } from "../interfaces/ICreator1155Initializer.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import { ContractVersionBase } from "../version/ContractVersionBase.sol";
import { CreatorPermissionControl } from "../permissions/CreatorPermissionControl.sol";
import { CreatorRendererControl } from "../renderer/CreatorRendererControl.sol";
import { CreatorRoyaltiesControl } from "../royalties/CreatorRoyaltiesControl.sol";
import { ICreatorCommands } from "../interfaces/ICreatorCommands.sol";
import { IMinter1155 } from "../interfaces/IMinter1155.sol";
import { IRenderer1155 } from "../interfaces/IRenderer1155.sol";
import { ITransferHookReceiver } from "../interfaces/ITransferHookReceiver.sol";
import { IFactoryManagedUpgradeGate } from "../interfaces/IFactoryManagedUpgradeGate.sol";
import { ICreator1155 } from "../interfaces/ICreator1155.sol";
import { LegacyNamingControl } from "../legacy-naming/LegacyNamingControl.sol";
import { PublicMulticall } from "../utils/PublicMulticall.sol";
import { SharedBaseConstants } from "../shared/SharedBaseConstants.sol";
import { TransferHelperUtils } from "../utils/TransferHelperUtils.sol";
import { Creator1155StorageV1 } from "./Creator1155StorageV1.sol";
import { ERC1155RewardsStorageV1 } from "../rewards/abstract/ERC1155RewardsStorageV1.sol";
import { RewardSplits, RewardSplitsLib } from "../rewards/abstract/RewardSplits.sol";

/// @title Creator1155Impl
/// @notice The core implementation contract for a creator's 1155 token
contract Creator1155Impl is
    ICreator1155,
    ICreator1155Initializer,
    ContractVersionBase,
    ReentrancyGuardUpgradeable,
    PublicMulticall,
    ERC1155Upgradeable,
    UUPSUpgradeable,
    CreatorRendererControl,
    LegacyNamingControl,
    Creator1155StorageV1,
    CreatorPermissionControl,
    CreatorRoyaltiesControl,
    RewardSplits,
    ERC1155RewardsStorageV1
{
    /// @notice This user role allows for any action to be performed
    uint256 public constant PERMISSION_BIT_ADMIN = 2 ** 1;
    /// @notice This user role allows for only mint actions to be performed
    uint256 public constant PERMISSION_BIT_MINTER = 2 ** 2;

    /// @notice This user role allows for only managing sales configurations
    uint256 public constant PERMISSION_BIT_SALES = 2 ** 3;
    /// @notice This user role allows for only managing metadata configuration
    uint256 public constant PERMISSION_BIT_METADATA = 2 ** 4;
    /// @notice This user role allows for only withdrawing funds and setting funds withdraw address
    uint256 public constant PERMISSION_BIT_FUNDS_MANAGER = 2 ** 5;
    /// @notice Factory contract
    IFactoryManagedUpgradeGate internal immutable factory;

    uint256 public immutable MINT_FEE;

    constructor(
        uint256 _mintFeeAmount,
        address _mintFeeRecipient,
        address _factory,
        address _protocolRewards
    ) RewardSplits(_protocolRewards, _mintFeeRecipient)
        initializer
    {
        MINT_FEE = _mintFeeAmount;
        factory = IFactoryManagedUpgradeGate(_factory);
    }

    /// @notice Initializes the contract
    /// @param contractName the legacy on-chain contract name
    /// @param newContractURI The contract URI
    /// @param defaultRoyaltyConfiguration The default royalty configuration
    /// @param defaultAdmin The default admin to manage the token
    /// @param setupActions The setup actions to run, if any
    function initialize(
        string memory contractName,
        string memory newContractURI,
        RoyaltyConfiguration memory defaultRoyaltyConfiguration,
        address payable defaultAdmin,
        bytes[] calldata setupActions
    )
        external
        nonReentrant
        initializer
    {
        // We are not initalizing the OZ 1155 implementation
        // to save contract storage space and runtime
        // since the only thing affected here is the uri.
        // __ERC1155_init("");

        // Setup uups
        __UUPSUpgradeable_init();

        // Setup re-entracy guard
        __ReentrancyGuard_init();

        // Setup contract-default token ID
        _setupDefaultToken(defaultAdmin, newContractURI, defaultRoyaltyConfiguration);

        // Set owner to default admin
        _setOwner(defaultAdmin);

        _setFundsRecipient(defaultAdmin);

        _setName(contractName);

        // Run Setup actions
        if (setupActions.length > 0) {
            // Temporarily make sender admin
            _addPermission(CONTRACT_BASE_ID, msg.sender, PERMISSION_BIT_ADMIN);

            // Make calls
            multicall(setupActions);

            // Remove admin
            _removePermission(CONTRACT_BASE_ID, msg.sender, PERMISSION_BIT_ADMIN);
        }
    }

    /// @notice sets up the global configuration for the 1155 contract
    /// @param newContractURI The contract URI
    /// @param defaultRoyaltyConfiguration The default royalty configuration
    function _setupDefaultToken(
        address defaultAdmin,
        string memory newContractURI,
        RoyaltyConfiguration memory defaultRoyaltyConfiguration
    )
        internal
    {
        // Add admin permission to default admin to manage contract
        _addPermission(CONTRACT_BASE_ID, defaultAdmin, PERMISSION_BIT_ADMIN);

        // Mint token ID 0 / don't allow any user mints
        _setupNewToken(newContractURI, 0, false);

        // Update default royalties
        _updateRoyalties(CONTRACT_BASE_ID, defaultRoyaltyConfiguration);
    }

    /// @notice Updates the royalty configuration for a token
    /// @param tokenId The token ID to update
    /// @param newConfiguration The new royalty configuration
    function updateRoyaltiesForToken(
        uint256 tokenId,
        RoyaltyConfiguration memory newConfiguration
    )
        external
        onlyAdminOrRole(tokenId, PERMISSION_BIT_FUNDS_MANAGER)
    {
        _updateRoyalties(tokenId, newConfiguration);
    }

    /// @notice remove this function from openzeppelin impl
    /// @dev This makes this internal function a no-op
    function _setURI(string memory newuri) internal virtual override { }

    /// @notice This gets the next token in line to be minted when minting linearly (default behavior) and updates the
    /// counter
    function _getAndUpdateNextTokenId() internal returns (uint256) {
        unchecked {
            return nextTokenId++;
        }
    }

    /// @notice Ensure that the next token ID is correct
    /// @dev This reverts if the invariant doesn't match. This is used for multicall token id assumptions
    /// @param lastTokenId The last token ID
    function assumeLastTokenIdMatches(uint256 lastTokenId) external view {
        unchecked {
            if (nextTokenId - 1 != lastTokenId) {
                revert TokenIdMismatch(lastTokenId, nextTokenId - 1);
            }
        }
    }

    /// @notice Checks if a user either has a role for a token or if they are the admin
    /// @dev This is an internal function that is called by the external getter and internal functions
    /// @param user The user to check
    /// @param tokenId The token ID to check
    /// @param role The role to check
    /// @return true or false if the permission exists for the user given the token id
    function _isAdminOrRole(address user, uint256 tokenId, uint256 role) internal view returns (bool) {
        return _hasAnyPermission(tokenId, user, PERMISSION_BIT_ADMIN | role);
    }

    /// @notice Checks if a user either has a role for a token or if they are the admin
    /// @param user The user to check
    /// @param tokenId The token ID to check
    /// @param role The role to check
    /// @return true or false if the permission exists for the user given the token id
    function isAdminOrRole(address user, uint256 tokenId, uint256 role) external view returns (bool) {
        return _isAdminOrRole(user, tokenId, role);
    }

    /// @notice Checks if the user is an admin for the given tokenId
    /// @dev This function reverts if the permission does not exist for the given user and tokenId
    /// @param user user to check
    /// @param tokenId tokenId to check
    /// @param role role to check for admin
    function _requireAdminOrRole(address user, uint256 tokenId, uint256 role) internal view {
        if (
            !(
                _hasAnyPermission(tokenId, user, PERMISSION_BIT_ADMIN | role)
                    || _hasAnyPermission(CONTRACT_BASE_ID, user, PERMISSION_BIT_ADMIN | role)
            )
        ) {
            revert UserMissingRoleForToken(user, tokenId, role);
        }
    }

    /// @notice Checks if the user is an admin
    /// @dev This reverts if the user is not an admin for the given token id or contract
    /// @param user user to check
    /// @param tokenId tokenId to check
    function _requireAdmin(address user, uint256 tokenId) internal view {
        if (
            !(
                _hasAnyPermission(tokenId, user, PERMISSION_BIT_ADMIN)
                    || _hasAnyPermission(CONTRACT_BASE_ID, user, PERMISSION_BIT_ADMIN)
            )
        ) {
            revert UserMissingRoleForToken(user, tokenId, PERMISSION_BIT_ADMIN);
        }
    }

    /// @notice Modifier checking if the user is an admin or has a role
    /// @dev This reverts if the msg.sender is not an admin for the given token id or contract
    /// @param tokenId tokenId to check
    /// @param role role to check
    modifier onlyAdminOrRole(uint256 tokenId, uint256 role) {
        _requireAdminOrRole(msg.sender, tokenId, role);
        _;
    }

    /// @notice Modifier checking if the user is an admin
    /// @dev This reverts if the msg.sender is not an admin for the given token id or contract
    /// @param tokenId tokenId to check
    modifier onlyAdmin(uint256 tokenId) {
        _requireAdmin(msg.sender, tokenId);
        _;
    }

    /// @notice Modifier checking if the requested quantity of tokens can be minted for the tokenId
    /// @dev This reverts if the number that can be minted is exceeded
    /// @param tokenId token id to check available allowed quantity
    /// @param quantity requested to be minted
    modifier canMintQuantity(uint256 tokenId, uint256 quantity) {
        _requireCanMintQuantity(tokenId, quantity);
        _;
    }

    /// @notice Only from approved address for burn
    /// @param from address that the tokens will be burned from, validate that this is msg.sender or that msg.sender is
    /// approved
    modifier onlyFromApprovedForBurn(address from) {
        if (from != msg.sender && !isApprovedForAll(from, msg.sender)) {
            revert Burn_NotOwnerOrApproved(msg.sender, from);
        }

        _;
    }

    /// @notice Checks if a user can mint a quantity of a token
    /// @dev Reverts if the mint exceeds the allowed quantity (or if the token does not exist)
    /// @param tokenId The token ID to check
    /// @param quantity The quantity of tokens to mint to check
    function _requireCanMintQuantity(uint256 tokenId, uint256 quantity) internal view {
        TokenData storage tokenInformation = tokens[tokenId];
        if (tokenInformation.totalMinted + quantity > tokenInformation.maxSupply) {
            revert CannotMintMoreTokens(tokenId, quantity, tokenInformation.totalMinted, tokenInformation.maxSupply);
        }
    }

    /// @notice Set up a new token
    /// @param newURI The URI for the token
    /// @param maxSupply The maximum supply of the token
    /// @param isSoulbound Whether the token is soulbound
    function setupNewToken(
        string calldata newURI,
        uint256 maxSupply,
        bool isSoulbound
    )
        public
        onlyAdminOrRole(CONTRACT_BASE_ID, PERMISSION_BIT_MINTER)
        nonReentrant
        returns (uint256)
    {
        uint256 tokenId = _setupNewTokenAndPermission(newURI, maxSupply, msg.sender, PERMISSION_BIT_ADMIN, isSoulbound);

        return tokenId;
    }

    /// @notice Set up a new token with a create referral
    /// @param newURI The URI for the token
    /// @param maxSupply The maximum supply of the token
    /// @param createReferral The address of the create referral
    /// @param isSoulbound Whether the token is soulbound
    function setupNewTokenWithCreateReferral(
        string calldata newURI,
        uint256 maxSupply,
        address createReferral,
        bool isSoulbound  
    ) public onlyAdminOrRole(CONTRACT_BASE_ID, PERMISSION_BIT_MINTER) nonReentrant returns (uint256) {
        uint256 tokenId = _setupNewTokenAndPermission(newURI, maxSupply, msg.sender, PERMISSION_BIT_ADMIN, isSoulbound);

        _setCreateReferral(tokenId, createReferral);

        return tokenId;
    }

    function _setupNewTokenAndPermission(string memory newURI, uint256 maxSupply, address user, uint256 permission, bool isSoulbound) internal returns (uint256) {
        uint256 tokenId = _setupNewToken(newURI, maxSupply, isSoulbound);

        _addPermission(tokenId, user, permission);

        if (bytes(newURI).length > 0) {
            emit URI(newURI, tokenId);
        }

        emit SetupNewToken(tokenId, user, newURI, maxSupply);

        return tokenId;
    }

    /// @notice Update the token URI for a token
    /// @param tokenId The token ID to update the URI for
    /// @param _newURI The new URI
    function updateTokenURI(
        uint256 tokenId,
        string memory _newURI
    )
        external
        onlyAdminOrRole(tokenId, PERMISSION_BIT_METADATA)
    {
        if (tokenId == CONTRACT_BASE_ID) {
            revert();
        }
        emit URI(_newURI, tokenId);
        tokens[tokenId].uri = _newURI;
    }

    /// @notice Update the global contract metadata
    /// @param _newURI The new contract URI
    /// @param _newName The new contract name
    function updateContractMetadata(
        string memory _newURI,
        string memory _newName
    )
        external
        onlyAdminOrRole(0, PERMISSION_BIT_METADATA)
    {
        tokens[CONTRACT_BASE_ID].uri = _newURI;
        _setName(_newName);
        emit ContractMetadataUpdated(msg.sender, _newURI, _newName);
    }

    function _setupNewToken(string memory newURI, uint256 maxSupply, bool isSoulbound) internal returns (uint256 tokenId) {
        tokenId = _getAndUpdateNextTokenId();
        TokenData memory tokenData = TokenData({ uri: newURI, maxSupply: maxSupply, totalMinted: 0, isSoulbound: isSoulbound });
        tokens[tokenId] = tokenData;
        emit UpdatedToken(msg.sender, tokenId, tokenData);
        emit SetupSoulbound(tokenId, isSoulbound);
    }

    /// @notice Add a role to a user for a token
    /// @param tokenId The token ID to add the role to
    /// @param user The user to add the role to
    /// @param permissionBits The permission bit to add
    function addPermission(uint256 tokenId, address user, uint256 permissionBits) external onlyAdmin(tokenId) {
        _addPermission(tokenId, user, permissionBits);
    }

    /// @notice Remove a role from a user for a token
    /// @param tokenId The token ID to remove the role from
    /// @param user The user to remove the role from
    /// @param permissionBits The permission bit to remove
    function removePermission(uint256 tokenId, address user, uint256 permissionBits) external {
        address sender = msg.sender;

        // Check if the user is an admin if they do not have the roles they are attempting to remove.
        if (!(user == sender && _hasAllPermissions(tokenId, sender, permissionBits))) {
            // Ensure that the sender of this message is an admin
            _requireAdmin(sender, tokenId);
        }

        _removePermission(tokenId, user, permissionBits);

        // Clear owner field on contract if removed permission is owner.
        if (tokenId == CONTRACT_BASE_ID && user == config.owner && !_hasAnyPermission(CONTRACT_BASE_ID, user, PERMISSION_BIT_ADMIN)) {
            _setOwner(address(0));
        }
    }

    /// @notice Set the owner of the contract
    /// @param newOwner The new owner of the contract
    function setOwner(address newOwner) external onlyAdmin(CONTRACT_BASE_ID) {
        if (!_hasAnyPermission(CONTRACT_BASE_ID, newOwner, PERMISSION_BIT_ADMIN)) {
            revert NewOwnerNeedsToBeAdmin();
        }

        // Update owner field
        _setOwner(newOwner);
    }

    /// @notice Getter for the owner singleton of the contract for outside interfaces
    /// @return the owner of the contract singleton for compat.
    function owner() external view returns (address) {
        return config.owner;
    }

    /// @notice AdminMint that only checks if the requested quantity can be minted and has a re-entrant guard
    /// @param recipient recipient for admin minted tokens
    /// @param tokenId token id to mint
    /// @param quantity quantity to mint
    /// @param data callback data as specified by the 1155 spec
    function _adminMint(address recipient, uint256 tokenId, uint256 quantity, bytes memory data) internal {
        _mint(recipient, tokenId, quantity, data);
    }

    /// @notice Mint a token to a user as the admin or minter
    /// @param recipient The recipient of the token
    /// @param tokenId The token ID to mint
    /// @param quantity The quantity of tokens to mint
    /// @param data The data to pass to the onERC1155Received function
    function adminMint(
        address recipient,
        uint256 tokenId,
        uint256 quantity,
        bytes memory data
    )
        external
        nonReentrant
        onlyAdminOrRole(tokenId, PERMISSION_BIT_MINTER)
    {
        // Call internal admin mint
        _adminMint(recipient, tokenId, quantity, data);
        emit AdminMinted(msg.sender, recipient, tokenId, quantity);
    }

    /// @notice Batch mint tokens to a user as the admin or minter
    /// @param recipient The recipient of the tokens
    /// @param tokenIds The token IDs to mint
    /// @param quantities The quantities of tokens to mint
    /// @param data The data to pass to the onERC1155BatchReceived function
    function adminMintBatch(
        address recipient,
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        bytes memory data
    )
        external
        nonReentrant
    {
        bool isGlobalAdminOrMinter = _isAdminOrRole(msg.sender, CONTRACT_BASE_ID, PERMISSION_BIT_MINTER);

        for (uint256 i = 0; i < tokenIds.length; ++i) {
            if (!isGlobalAdminOrMinter) {
                _requireAdminOrRole(msg.sender, tokenIds[i], PERMISSION_BIT_MINTER);
            }
        }
        _mintBatch(recipient, tokenIds, quantities, data);
        emit AdminMintedBatch(msg.sender, recipient, tokenIds, quantities);
    }

    /// @notice Mint tokens given a minter contract and minter arguments
    /// @param minter The minter contract to use
    /// @param tokenId The token ID to mint
    /// @param quantity The quantity of tokens to mint
    /// @param minterArguments The arguments to pass to the minter
    function mint(
        IMinter1155 minter,
        uint256 tokenId,
        uint256 quantity,
        bytes calldata minterArguments
    )
        external
        payable
        nonReentrant
    {
        _mint(minter, tokenId, quantity, new address[](0), minterArguments);
    }

    /// @notice Mint tokens and payout rewards given a minter contract, minter arguments, and rewards arguments
    /// @param minter The minter contract to use
    /// @param tokenId The token ID to mint
    /// @param quantity The quantity of tokens to mint
    /// @param rewardsRecipients The addresses of rewards arguments - rewardsRecipients[0] = mintReferral, rewardsRecipients[1] = platformReferral
    /// @param minterArguments The arguments to pass to the minter
    function mintWithRewards(
        IMinter1155 minter,
        uint256 tokenId,
        uint256 quantity,
        address[] calldata rewardsRecipients,
        bytes calldata minterArguments
    ) external payable nonReentrant {
        _mint(minter, tokenId, quantity, rewardsRecipients, minterArguments);
    }

    function _mintAndHandleRewards(
        IMinter1155 minter,
        address[] memory rewardsRecipients,
        uint256 valueSent,
        uint256 totalReward,
        uint256 tokenId,
        uint256 quantity,
        bytes calldata minterArguments
    ) private {
        uint256 ethValueSent = _handleRewardsAndGetValueRemaining(valueSent, totalReward, tokenId, rewardsRecipients);

        _executeCommands(minter.requestMint(msg.sender, tokenId, quantity, ethValueSent, minterArguments).commands, ethValueSent, tokenId);
        emit Purchased(msg.sender, address(minter), tokenId, quantity, valueSent);
    }

    function _handleRewardsAndGetValueRemaining(
        uint256 totalSentValue,
        uint256 totalReward,
        uint256 tokenId,
        address[] memory rewardsRecipients
    ) internal returns (uint256 valueRemaining) {
        // 1. Get rewards recipients

        // create referral is pulled from storage, if it's not set, defaults to freee reward recipient
        address createReferral = createReferrals[tokenId];
        if (createReferral == address(0)) {
            createReferral = rewardRecipient;
        }

        // mint referral is passed in arguments to minting functions; if it's not set, defaults to freee reward recipient
        address mintReferral = rewardsRecipients.length > 0 ? rewardsRecipients[0] : rewardRecipient;
        if (mintReferral == address(0)) {
            mintReferral = rewardRecipient;
        }

        // creator reward recipient is pulled from storage, if it's not set, defaults to freee reward recipient
        address creatorRewardRecipient = getCreatorRewardRecipient(tokenId);
        if (creatorRewardRecipient == address(0)) {
            creatorRewardRecipient = rewardRecipient;
        }

        // first minter is pulled from storage, if it's not set, defaults to creator reward recipient (which is freee if there is no creator reward recipient set)
        address firstMinter = firstMinters[tokenId];
        if (firstMinter == address(0)) {
            firstMinter = creatorRewardRecipient;
        }

        // 2. Get rewards amounts - which varies if its a paid or free mint

        RewardsSettings memory settings;
        if (totalSentValue < totalReward) {
            revert INVALID_ETH_AMOUNT();
            // if value sent is the same as the reward amount, we assume its a free mint
        } else if (totalSentValue == totalReward) {
            settings = RewardSplitsLib.getRewards(false, totalReward);
            // otherwise, we assume its a paid mint
        } else {
            settings = RewardSplitsLib.getRewards(true, totalReward);

            unchecked {
                valueRemaining = totalSentValue - totalReward;
            }
        }

        // 3. Deposit rewards rewards

        protocolRewards.depositRewards{value: totalReward}(
            // if there was no creator reward amount, 0 out that address
            settings.creatorReward == 0 ? address(0) : creatorRewardRecipient,
            settings.creatorReward,
            createReferral,
            settings.createReferralReward,
            mintReferral,
            settings.mintReferralReward,
            firstMinter,
            settings.firstMinterReward,
            rewardRecipient,
            settings.freeeReward
        );
    }

    function _mint(IMinter1155 minter, uint256 tokenId, uint256 quantity, address[] memory rewardsRecipients, bytes calldata minterArguments) private {
        // Require admin from the minter to mint
        _requireAdminOrRole(address(minter), tokenId, PERMISSION_BIT_MINTER);

        uint256 totalReward = MINT_FEE * quantity;

        _mintAndHandleRewards(minter, rewardsRecipients, msg.value, totalReward, tokenId, quantity, minterArguments);
    }

    function mintFee() external view returns (uint256) {
        return MINT_FEE;
    }

    /// @notice Get the creator reward recipient address for a specific token.
    /// @param tokenId The token id to get the creator reward recipient for
    /// @dev Returns the royalty recipient address for the token if set; otherwise uses the fundsRecipient.
    /// If both are not set, this contract will be set as the recipient, and an account with
    /// `PERMISSION_BIT_FUNDS_MANAGER` will be able to withdraw via the `withdrawFor` function.
    function getCreatorRewardRecipient(uint256 tokenId) public view returns (address) {
        address royaltyRecipient = getRoyalties(tokenId).royaltyRecipient;

        if (royaltyRecipient != address(0)) {
            return royaltyRecipient;
        }

        if (config.fundsRecipient != address(0)) {
            return config.fundsRecipient;
        }

        return address(this);
    }

    /// @notice Set a metadata renderer for a token
    /// @param tokenId The token ID to set the renderer for
    /// @param renderer The renderer to set
    function setTokenMetadataRenderer(
        uint256 tokenId,
        IRenderer1155 renderer
    )
        external
        nonReentrant
        onlyAdminOrRole(tokenId, PERMISSION_BIT_METADATA)
    {
        _setRenderer(tokenId, renderer);

        if (tokenId == 0) {
            emit ContractRendererUpdated(renderer);
        } else {
            // We don't know the uri from the renderer but can emit a notification to the indexer here
            emit URI("", tokenId);
        }
    }

    /// Execute Minter Commands ///

    /// @notice Internal functions to execute commands returned by the minter
    /// @param commands list of command structs
    /// @param ethValueSent the ethereum value sent in the mint transaction into the contract
    /// @param tokenId the token id the user requested to mint (0 if the token id is set by the minter itself across the
    /// whole contract)
    function _executeCommands(
        ICreatorCommands.Command[] memory commands,
        uint256 ethValueSent,
        uint256 tokenId
    )
        internal
    {
        for (uint256 i = 0; i < commands.length; ++i) {
            ICreatorCommands.CreatorActions method = commands[i].method;
            if (method == ICreatorCommands.CreatorActions.SEND_ETH) {
                (address recipient, uint256 amount) = abi.decode(commands[i].args, (address, uint256));
                if (ethValueSent > amount) {
                    revert Mint_InsolventSaleTransfer();
                }
                if (
                    !TransferHelperUtils.safeSendETH(recipient, amount, TransferHelperUtils.FUNDS_SEND_NORMAL_GAS_LIMIT)
                ) {
                    revert Mint_ValueTransferFail();
                }
            } else if (method == ICreatorCommands.CreatorActions.MINT) {
                (address recipient, uint256 mintTokenId, uint256 quantity) =
                    abi.decode(commands[i].args, (address, uint256, uint256));
                if (tokenId != 0 && mintTokenId != tokenId) {
                    revert Mint_TokenIDMintNotAllowed();
                }
                _mint(recipient, tokenId, quantity, "");
            } else {
                // no-op
            }
        }
    }

    /// @notice Token info getter
    /// @param tokenId token id to get info for
    /// @return TokenData struct returned
    function getTokenInfo(uint256 tokenId) external view returns (TokenData memory) {
        return tokens[tokenId];
    }

    /// @notice Proxy setter for sale contracts (only callable by SALES permission or admin)
    /// @param tokenId The token ID to call the sale contract with
    /// @param salesConfig The sales config contract to call
    /// @param data The data to pass to the sales config contract
    function callSale(
        uint256 tokenId,
        IMinter1155 salesConfig,
        bytes calldata data
    )
        external
        onlyAdminOrRole(tokenId, PERMISSION_BIT_SALES)
    {
        _requireAdminOrRole(address(salesConfig), tokenId, PERMISSION_BIT_MINTER);
        if (!salesConfig.supportsInterface(type(IMinter1155).interfaceId)) {
            revert Sale_CannotCallNonSalesContract(address(salesConfig));
        }

        // Get the token id encoded in the calldata for the sales config
        // Assume that it is the first 32 bytes following the function selector
        uint256 encodedTokenId = uint256(bytes32(data[4:36]));

        // Ensure the encoded token id matches the passed token id
        if (encodedTokenId != tokenId) {
            revert Call_TokenIdMismatch();
        }

        (bool success, bytes memory why) = address(salesConfig).call(data);
        if (!success) {
            revert CallFailed(why);
        }
    }

    /// @notice Proxy setter for renderer contracts (only callable by METADATA permission or admin)
    /// @param tokenId The token ID to call the renderer contract with
    /// @param data The data to pass to the renderer contract
    function callRenderer(
        uint256 tokenId,
        bytes memory data
    )
        external
        onlyAdminOrRole(tokenId, PERMISSION_BIT_METADATA)
    {
        // We assume any renderers set are checked for EIP165 signature during write stage.
        (bool success, bytes memory why) = address(getCustomRenderer(tokenId)).call(data);
        if (!success) {
            revert CallFailed(why);
        }
    }

    /// @notice Returns true if the contract implements the interface defined by interfaceId
    /// @param interfaceId The interface to check for
    /// @return if the interfaceId is marked as supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(CreatorRoyaltiesControl, ERC1155Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || interfaceId == type(ICreator1155).interfaceId
            || ERC1155Upgradeable.supportsInterface(interfaceId);
    }

    /// Generic 1155 function overrides ///

    /// @notice Mint function that 1) checks quantity and 2) handles supply royalty 3) keeps track of allowed tokens
    /// @param to to mint to
    /// @param id token id to mint
    /// @param amount of tokens to mint
    /// @param data as specified by 1155 standard
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual override {
        _requireCanMintQuantity(id, amount);

        tokens[id].totalMinted += amount;

        super._mint(to, id, amount, data);
    }

    /// @notice Mint batch function that 1) checks quantity and 2) handles supply royalty 3) keeps track of allowed
    /// tokens
    /// @param to to mint to
    /// @param ids token ids to mint
    /// @param amounts of tokens to mint
    /// @param data as specified by 1155 standard
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        virtual
        override
    {
        uint256 numTokens = ids.length;
        for (uint256 i = 0; i < numTokens; ++i) {
            _requireCanMintQuantity(ids[i], amounts[i]);
            tokens[ids[i]].totalMinted += amounts[i];
        }
        super._mintBatch(to, ids, amounts, data);
    }

    /// @notice Burns a batch of tokens
    /// @dev Only the current owner is allowed to burn
    /// @param from the user to burn from
    /// @param tokenIds The token ID to burn
    /// @param amounts The amount of tokens to burn
    function burnBatch(address from, uint256[] calldata tokenIds, uint256[] calldata amounts) external {
        if (from != msg.sender && !isApprovedForAll(from, msg.sender)) {
            revert Burn_NotOwnerOrApproved(msg.sender, from);
        }

        _burnBatch(from, tokenIds, amounts);
    }

    function setTransferHook(ITransferHookReceiver transferHook) external onlyAdmin(CONTRACT_BASE_ID) {
        if (address(transferHook) != address(0)) {
            if (!transferHook.supportsInterface(type(ITransferHookReceiver).interfaceId)) {
                revert Config_TransferHookNotSupported(address(transferHook));
            }
        }

        config.transferHook = transferHook;
        emit ConfigUpdated(msg.sender, ConfigUpdate.TRANSFER_HOOK, config);
    }

    /// @notice Hook before token transfer that checks for a transfer hook integration
    /// @param operator operator moving the tokens
    /// @param from from address
    /// @param to to address
    /// @param ids token ids to move
    /// @param amounts amounts of tokens
    /// @param data data of tokens
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        if (address(config.transferHook) != address(0)) {
            config.transferHook.onTokenTransferBatch({
                target: address(this),
                operator: operator,
                from: from,
                to: to,
                ids: ids,
                amounts: amounts,
                data: data
            });
        }

        for (uint256 i = 0; i < ids.length; i++) {
            if (tokens[ids[i]].isSoulbound && from != address(0)) {
                revert Transfer_NotAllowed();
            }
        }
    }

    /// @notice Returns the URI for the contract
    function contractURI() external view returns (string memory) {
        IRenderer1155 customRenderer = getCustomRenderer(CONTRACT_BASE_ID);
        if (address(customRenderer) != address(0)) {
            return customRenderer.contractURI();
        }
        return uri(0);
    }

    /// @notice Returns the URI for a token
    /// @param tokenId The token ID to return the URI for
    function uri(uint256 tokenId)
        public
        view
        override(ERC1155Upgradeable, IERC1155MetadataURIUpgradeable)
        returns (string memory)
    {
        if (bytes(tokens[tokenId].uri).length > 0) {
            return tokens[tokenId].uri;
        }
        return _render(tokenId);
    }

    /// @notice Internal setter for contract admin with no access checks
    /// @param newOwner new owner address
    function _setOwner(address newOwner) internal {
        address lastOwner = config.owner;
        config.owner = newOwner;

        emit OwnershipTransferred(lastOwner, newOwner);
        emit ConfigUpdated(msg.sender, ConfigUpdate.OWNER, config);
    }

    /// @notice Set funds recipient address
    /// @param fundsRecipient new funds recipient address
    function setFundsRecipient(address payable fundsRecipient)
        external
        onlyAdminOrRole(CONTRACT_BASE_ID, PERMISSION_BIT_FUNDS_MANAGER)
    {
        _setFundsRecipient(fundsRecipient);
    }

    /// @notice Internal no-checks set funds recipient address
    /// @param fundsRecipient new funds recipient address
    function _setFundsRecipient(address payable fundsRecipient) internal {
        config.fundsRecipient = fundsRecipient;
        emit ConfigUpdated(msg.sender, ConfigUpdate.FUNDS_RECIPIENT, config);
    }

    /// @notice Allows the create referral to update the address that can claim their rewards
    function updateCreateReferral(uint256 tokenId, address recipient) external {
        if (msg.sender != createReferrals[tokenId]) revert ONLY_CREATE_REFERRAL();

        _setCreateReferral(tokenId, recipient);
    }

    function _setCreateReferral(uint256 tokenId, address recipient) internal {
        createReferrals[tokenId] = recipient;
    }

    /// @notice Withdraws all ETH from the contract to the funds recipient address
    function withdraw() public onlyAdminOrRole(CONTRACT_BASE_ID, PERMISSION_BIT_FUNDS_MANAGER) {
        uint256 contractValue = address(this).balance;
        if (
            !TransferHelperUtils.safeSendETH(
                config.fundsRecipient, contractValue, TransferHelperUtils.FUNDS_SEND_NORMAL_GAS_LIMIT
            )
        ) {
            revert ETHWithdrawFailed(config.fundsRecipient, contractValue);
        }
    }

    function setSoulbound(bool _isSoulbound, uint256 tokenId) external onlyAdminOrRole(tokenId, PERMISSION_BIT_ADMIN) {
        tokens[tokenId].isSoulbound = _isSoulbound;
        emit SetupSoulbound(tokenId, _isSoulbound);
    }

    receive() external payable {}

    ///                                                          ///
    ///                         MANAGER UPGRADE                  ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyAdmin(CONTRACT_BASE_ID) {
        if (!factory.isRegisteredUpgradePath(_getImplementation(), _newImpl)) {
            revert();
        }
    }

     /// @notice Returns the current implementation address
    function implementation() external view returns (address) {
        return _getImplementation();
    }
}
