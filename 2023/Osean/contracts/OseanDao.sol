// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

// @author OSEAN DAO based on THIRDWEB vote
// THIS IS THE OFFICIAL OSEAN DAO GOVERNANCE CONTRACT

// Base
import "@thirdweb-dev/contracts/infra/interface/IThirdwebContract.sol";

// Governance
import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";

// Interfaces
import "./interface/Uniswap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Meta transactions
import "@thirdweb-dev/contracts/external-deps/openzeppelin/metatx/ERC2771ContextUpgradeable.sol";


contract OseanDao is
    Initializable,
    IThirdwebContract,
    ERC2771ContextUpgradeable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable
{
    bytes32 private constant MODULE_TYPE = bytes32("VoteERC20");
    uint256 private constant VERSION = 1;

    string public contractURI;
    uint256 public proposalIndex;

    struct Proposal {
        uint256 proposalId;
        address proposer;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        string description;
    }

    // @dev proposal index => Proposal
    mapping(uint256 => Proposal) public proposals;

    // The PancakeSwap router address for swapping OSEAN tokens for WBNB.
    address public uniswapRouterAddress;

    // Address of OSEAN token on BSC chain
    address public osean;

    // Address of USDT token on BSC chain
    address public usdt;

    // PancakeSwap router interface.
    IUniswapV2Router02 private uniswapRouter;

    constructor(
        string memory _name,
        string memory _contractURI,
        address[] memory _trustedForwarders,
        address _token,
        address _uniswapRouterAddress,
        address _osean,
        address _usdt,
        uint256 _initialVotingDelay,
        uint256 _initialVotingPeriod,
        uint256 _initialProposalThreshold,
        uint256 _initialVoteQuorumFraction
    ) initializer {
        // Initialize inherited contracts, most base-like -> most derived.
        __ERC2771Context_init(_trustedForwarders);
        __Governor_init(_name);
        __GovernorSettings_init(_initialVotingDelay, _initialVotingPeriod, _initialProposalThreshold);
        __GovernorVotes_init(IVotesUpgradeable(_token));
        __GovernorVotesQuorumFraction_init(_initialVoteQuorumFraction);
        
        osean = _osean;
        usdt =_usdt;

        uniswapRouterAddress = _uniswapRouterAddress;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(uniswapRouterAddress);
        uniswapRouter = _uniswapV2Router;

        // Initialize this contract's state.
        contractURI = _contractURI;

    }
    
    // @dev Initializes the contract, like a constructor.
    function initialize(
        string memory _name,
        string memory _contractURI,
        address[] memory _trustedForwarders,
        address _token,
        uint256 _initialVotingDelay,
        uint256 _initialVotingPeriod,
        uint256 _initialProposalThreshold,
        uint256 _initialVoteQuorumFraction
    ) external initializer {
        // Initialize inherited contracts, most base-like -> most derived.
        __ERC2771Context_init(_trustedForwarders);
        __Governor_init(_name);
        __GovernorSettings_init(_initialVotingDelay, _initialVotingPeriod, _initialProposalThreshold);
        __GovernorVotes_init(IVotesUpgradeable(_token));
        __GovernorVotesQuorumFraction_init(_initialVoteQuorumFraction);

        // Initialize this contract's state.
        contractURI = _contractURI;
    }

    // @dev Returns the module type of the contract.
    function contractType() external pure returns (bytes32) {
        return MODULE_TYPE;
    }

    // @dev Returns the version of the contract.
    function contractVersion() public pure override returns (uint8) {
        return uint8(VERSION);
    }

    /*
      @dev See {IGovernor-propose}.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256 proposalId) {
        proposalId = super.propose(targets, values, calldatas, description);

        proposals[proposalIndex] = Proposal({
            proposalId: proposalId,
            proposer: _msgSender(),
            targets: targets,
            values: values,
            signatures: new string[](targets.length),
            calldatas: calldatas,
            startBlock: proposalSnapshot(proposalId),
            endBlock: proposalDeadline(proposalId),
            description: description
        });

        proposalIndex += 1;
    }

    // @dev Returns all proposals made.
    function getAllProposals() external view returns (Proposal[] memory allProposals) {
        uint256 nextProposalIndex = proposalIndex;

        allProposals = new Proposal[](nextProposalIndex);
        for (uint256 i = 0; i < nextProposalIndex; i += 1) {
            allProposals[i] = proposals[i];
        }
    }

    function setContractURI(string calldata uri) external onlyGovernance {
        contractURI = uri;
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return GovernorSettingsUpgradeable.proposalThreshold();
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC721ReceiverUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function swapOSEANForBNB(uint256 amount) private {
        IERC20 oseanToken = IERC20(osean);

        oseanToken.approve(address(uniswapRouter), amount);


        address[] memory path = new address[](2);
        path[0] = address(oseanToken);
        path[1] = uniswapRouter.WETH();

        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    } 

    function swapOSEAN (uint256 amount) external onlyGovernance {
        swapOSEANForBNB(amount);
    }

    function swapBNBForOSEAN(uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = address(osean); // Replace with the OSEAN token address on BSC

        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapBNB(uint256 amount) external onlyGovernance {
        swapBNBForOSEAN(amount);
    }

    function swapBNBForUSDT(uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = address(usdt); // Replace with the USDT token address on BSC

        uniswapRouter.swapExactETHForTokens{value: amount}(
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapUSDT(uint256 amount) external onlyGovernance {
        swapBNBForUSDT(amount);
    }


     // Function to change the OSEAN token address
    function setOseanAddress(address _newOsean) public onlyGovernance {
        osean = _newOsean;
    }

    // Function to change the Uniswap Router address
    function setUniswapRouterAddress(address _newRouter) public onlyGovernance {
        uniswapRouterAddress = _newRouter;
        uniswapRouter = IUniswapV2Router02(_newRouter);
    }
}