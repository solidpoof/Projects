// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IFactoryV2 {
    event PairCreated(address indexed token0, address indexed token1, address lpPair, uint);
    function getPair(address tokenA, address tokenB) external view returns (address lpPair);
    function createPair(address tokenA, address tokenB) external returns (address lpPair);
}

interface IV2Pair {
    function factory() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function sync() external;
}

interface IRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function swapExactETHForTokens(
        uint amountOutMin, 
        address[] calldata path, 
        address to, uint deadline
    ) external payable returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IRouter02 is IRouter01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface Protections {
    function checkUser(address from, address to, uint256 amt) external returns (bool);
    function setLaunch(address _initialLpPair, uint32 _liqAddBlock, uint64 _liqAddStamp, uint8 dec) external;
    function setLpPair(address pair, bool enabled) external;
    function setProtections(bool _as, bool _ab) external;
    function removeSniper(address account) external;
    function withdraw() external;
}


interface Cashier {
    function setRewardsProperties(uint256 _minPeriod, uint256 _minReflection) external;
    function tally(address user, uint256 amount) external;
    function load(uint256 amount) external;
    function cashout(uint256 gas) external;
    function giveMeWelfarePlease(address hobo) external;
    function getTotalDistributed() external view returns(uint256);
    function getUserInfo(address user) external view returns(string memory, string memory, string memory, string memory);
    function getUserRealizedRewards(address user) external view returns (uint256);
    function getPendingRewards(address user) external view returns (uint256);
    function initialize() external;
    function getCurrentReward() external view returns (address);
}

contract LunaManiacs is IERC20 {
    mapping (address => uint256) _tOwned;
    mapping (address => bool) lpPairs;
    uint256 private timeSinceLastPair = 0;
    mapping (address => mapping (address => uint256)) _allowances;
    mapping (address => bool) private _isExcludedFromProtection;
    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) private _isExcludedFromLimits;
    mapping (address => bool) private _isExcludedFromDividends;
    mapping (address => bool) private _liquidityHolders;
    mapping (address => bool) private presaleAddresses;
    bool private allowedPresaleExclusion = true;

    uint256 constant private startingSupply = 100_000_000;
    string constant private _name = "Luna Maniacs";
    string constant private _symbol = "LUNAM";
    uint8 constant private _decimals = 18;
    uint256 constant private _tTotal = startingSupply * (10 ** _decimals);

    struct Fees {
        uint16 buyFee;
        uint16 sellFee;
        uint16 transferFee;
    }

    struct Ratios {
        uint16 rewards;
        uint16 marketing;
        uint16 total;
    }

    Fees public _taxRates = Fees({
        buyFee: 500,
        sellFee: 500,
        transferFee: 0
    });

    Ratios public _ratios = Ratios({
        rewards: 400,
        marketing: 100,
        total: 500
    });

    uint256 constant public maxBuyTaxes = 1000;
    uint256 constant public maxSellTaxes = 1000;
    uint256 constant public maxTransferTaxes = 1000;
    uint256 constant masterTaxDivisor = 10000;

    bool public taxesAreLocked;
    IRouter02 public dexRouter;
    address public lpPair;

    // LUNC MAINNET TOKEN CONTRACT ADDRESS
    address public LUNC = 0x156ab3346823B651294766e23e6Cf87254d68962;
    address constant public DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant private ZERO = 0x0000000000000000000000000000000000000000;
    address payable public marketingWallet = payable(0xbfEd6164FFE0E2B20BC5AED94B77d80ef5767f2D);

    uint256 private _maxTxAmount = (_tTotal * 1) / 100;
    uint256 private _maxWalletSize = (_tTotal * 2) / 100;

    Cashier cashier;
    uint256 reflectorGas = 300000;

    bool inSwap;
    bool public contractSwapEnabled = false;
    uint256 public swapThreshold;
    uint256 public swapAmount;
    bool public piContractSwapsEnabled;
    uint256 public piSwapPercent = 10;

    bool public processReflect = false;

    bool public tradingEnabled = false;
    bool public _hasLiqBeenAdded = false;
    Protections protections;

    address public pairedToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    IERC20 public IERC20_PairedToken = IERC20(pairedToken);

    modifier inSwapFlag() {
        inSwap = true;
        _;
        inSwap = false;
    }

    event ContractSwapEnabledUpdated(bool enabled);
    event AutoLiquify(uint256 amountBNB, uint256 amount);

    constructor () payable {
        // Set the owner.
        _owner = msg.sender;
        originalDeployer = msg.sender;

        _tOwned[_owner] = _tTotal;
        emit Transfer(ZERO, _owner, _tTotal);
        emit OwnershipTransferred(address(0), _owner);

        if (block.chainid == 56) {
            dexRouter = IRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        } else if (block.chainid == 97) {
            dexRouter = IRouter02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
            pairedToken = 0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684;
            IERC20_PairedToken = IERC20(0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684);
        } else if (block.chainid == 1 || block.chainid == 4) {
            dexRouter = IRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
            //Ropstein DAI 0xaD6D458402F60fD3Bd25163575031ACDce07538D
        } else if (block.chainid == 43114) {
            dexRouter = IRouter02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
        } else if (block.chainid == 250) {
            dexRouter = IRouter02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
        } else {
            revert();
        }

        address nativePair = IFactoryV2(dexRouter.factory()).createPair(dexRouter.WETH(), address(this));
        lpPair = IFactoryV2(dexRouter.factory()).createPair(pairedToken, address(this));
        lpPairs[lpPair] = true;
        lpPairs[nativePair] = true;

        _approve(_owner, address(dexRouter), type(uint256).max);
        _approve(address(this), address(dexRouter), type(uint256).max);
        IERC20_PairedToken.approve(address(dexRouter), type(uint256).max);

        _isExcludedFromFees[_owner] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[DEAD] = true;
        _isExcludedFromDividends[_owner] = true;
        _isExcludedFromDividends[lpPair] = true;
        _isExcludedFromDividends[address(this)] = true;
        _isExcludedFromDividends[DEAD] = true;
        _isExcludedFromDividends[ZERO] = true;

        // Exclude common lockers from dividends.
        _isExcludedFromDividends[0x407993575c91ce7643a4d4cCACc9A98c36eE1BBE] = true; // PinkLock
        _isExcludedFromDividends[0x663A5C229c09b049E36dCc11a9B0d4a8Eb9db214] = true; // Unicrypt (ETH)
    }

//===============================================================================================================
//===============================================================================================================
//===============================================================================================================
    // Ownable removed as a lib and added here to allow for custom transfers and renouncements.
    // This allows for removal of ownership privileges from the owner once renounced or transferred.

    address private _owner;

    modifier onlyOwner() { require(_owner == msg.sender, "Caller =/= owner."); _; }
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function transferOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Call renounceOwnership to transfer owner to the zero address.");
        require(newOwner != DEAD, "Call renounceOwnership to transfer owner to the zero address.");
        _isExcludedFromFees[_owner] = false;
        _isExcludedFromDividends[_owner] = false;
        _isExcludedFromFees[newOwner] = true;
        _isExcludedFromDividends[newOwner] = true;
        
        if (balanceOf(_owner) > 0) {
            finalizeTransfer(_owner, newOwner, balanceOf(_owner), false, false, true);
        }
        
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
        
    }

    function renounceOwnership() external onlyOwner {
        setExcludedFromFees(_owner, false);
        address oldOwner = _owner;
        _owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
    }

    address public originalDeployer;
    address public operator;

    // Function to set an operator to allow someone other the deployer to create things such as launchpads.
    // Only callable by original deployer.
    function setOperator(address newOperator) public {
        require(msg.sender == originalDeployer, "Can only be called by original deployer.");
        address oldOperator = operator;
        if (oldOperator != address(0)) {
            _liquidityHolders[oldOperator] = false;
            setExcludedFromFees(oldOperator, false);
            _isExcludedFromDividends[oldOperator] = false;
        }
        operator = newOperator;
        _liquidityHolders[newOperator] = true;
        setExcludedFromFees(newOperator, true);
        _isExcludedFromDividends[newOperator] = true;
    }

    function renounceOriginalDeployer() external {
        require(msg.sender == originalDeployer, "Can only be called by original deployer.");
        setOperator(address(0));
        originalDeployer = address(0);
    }

//===============================================================================================================
//===============================================================================================================
//===============================================================================================================

    receive() external payable {}

    function totalSupply() external pure override returns (uint256) { if (_tTotal == 0) { revert(); } return _tTotal; }
    function decimals() external pure override returns (uint8) { if (_tTotal == 0) { revert(); } return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return _owner; }
    function balanceOf(address account) public view override returns (uint256) { return _tOwned[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address sender, address spender, uint256 amount) internal {
        require(sender != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[sender][spender] = amount;
        emit Approval(sender, spender, amount);
    }

    function approveContractContingency() public onlyOwner returns (bool) {
        _approve(address(this), address(dexRouter), type(uint256).max);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transfer(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] -= amount;
        }

        return _transfer(sender, recipient, amount);
    }

    function setNewRouter(address newRouter) external onlyOwner {
        require(!_hasLiqBeenAdded, "Cannot change after liquidity.");
        IRouter02 _newRouter = IRouter02(newRouter);
        lpPairs[lpPair] = false;
        address get_pair = IFactoryV2(_newRouter.factory()).getPair(address(this), _newRouter.WETH());
        if (get_pair == address(0)) {
            lpPair = IFactoryV2(_newRouter.factory()).createPair(address(this), _newRouter.WETH());
        }
        else {
            lpPair = get_pair;
        }
        dexRouter = _newRouter;
        lpPairs[lpPair] = true;
        _isExcludedFromDividends[lpPair] = true;
        _approve(address(this), address(dexRouter), type(uint256).max);
    }

    function setLpPair(address pair, bool enabled) external onlyOwner {
        if (!enabled) {
            lpPairs[pair] = false;
            _isExcludedFromDividends[pair] = true;
            protections.setLpPair(pair, false);
        } else {
            if (timeSinceLastPair != 0) {
                require(block.timestamp - timeSinceLastPair > 3 days, "3 Day cooldown.");
            }
            require(!lpPairs[pair], "Pair already added to list.");
            lpPairs[pair] = true;
            timeSinceLastPair = block.timestamp;
            protections.setLpPair(pair, true);
        }
    }

    function setInitializers(address aInitializer, address cInitializer) external onlyOwner {
        require(!tradingEnabled);
        require(cInitializer != address(this) && aInitializer != address(this) && cInitializer != aInitializer);
        cashier = Cashier(cInitializer);
        protections = Protections(aInitializer);
    }

    function isExcludedFromFees(address account) external view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function isExcludedFromDividends(address account) external view returns(bool) {
        return _isExcludedFromDividends[account];
    }

    function isExcludedFromProtection(address account) external view returns (bool) {
        return _isExcludedFromProtection[account];
    }

    function isExcludedFromLimits(address account) external view returns (bool) {
        return _isExcludedFromLimits[account];
    }

    function setExcludedFromLimits(address account, bool enabled) external onlyOwner {
        _isExcludedFromLimits[account] = enabled;
    }

    function setDividendExcluded(address account, bool enabled) public onlyOwner {
        require(account != address(this) 
                && account != lpPair
                && account != DEAD);
        _isExcludedFromDividends[account] = enabled;
        if (enabled) {
            try cashier.tally(account, 0) {} catch {}
        } else {
            try cashier.tally(account, _tOwned[account]) {} catch {}
        }
    }

    function setExcludedFromFees(address account, bool enabled) public onlyOwner {
        _isExcludedFromFees[account] = enabled;
    }

    function setExcludedFromProtection(address account, bool enabled) external onlyOwner {
        _isExcludedFromProtection[account] = enabled;
    }

    function removeSniper(address account) external onlyOwner {
        protections.removeSniper(account);
    }

    function setProtectionSettings(bool _antiSnipe, bool _antiBlock) external onlyOwner {
        protections.setProtections(_antiSnipe, _antiBlock);
    }

    function setWallets(address payable marketing) external onlyOwner {
        require(marketing != address(0), "Cannot be zero address.");
        marketingWallet = payable(marketing);
    }

    function lockTaxes() external onlyOwner {
        // This will lock taxes at their current value forever, do not call this unless you're sure.
        taxesAreLocked = true;
    }

    function setTaxes(uint16 buyFee, uint16 sellFee, uint16 transferFee) external onlyOwner {
        require(!taxesAreLocked, "Taxes are locked.");
        require(buyFee <= maxBuyTaxes
                && sellFee <= maxSellTaxes
                && transferFee <= maxTransferTaxes,
                "Cannot exceed maximums.");
        _taxRates.buyFee = buyFee;
        _taxRates.sellFee = sellFee;
        _taxRates.transferFee = transferFee;
    }

    function setRatios(uint16 rewards, uint16 marketing) external onlyOwner {
        _ratios.rewards = rewards;
        _ratios.marketing = marketing;
        _ratios.total = rewards + marketing;
        uint256 total = _taxRates.buyFee + _taxRates.sellFee;
        require(_ratios.total <= total, "Cannot exceed sum of buy and sell fees.");
    }

    function setMaxTxPercent(uint256 percent, uint256 divisor) external onlyOwner {
        require((_tTotal * percent) / divisor >= (_tTotal * 5 / 1000), "Max Transaction amt must be above 0.5% of total supply.");
        _maxTxAmount = (_tTotal * percent) / divisor;
    }

    function setMaxWalletSize(uint256 percent, uint256 divisor) external onlyOwner {
        require((_tTotal * percent) / divisor >= (_tTotal / 100), "Max Wallet amt must be above 1% of total supply.");
        _maxWalletSize = (_tTotal * percent) / divisor;
    }

    function getMaxTX() public view returns (uint256) {
        return _maxTxAmount / (10**_decimals);
    }

    function getMaxWallet() public view returns (uint256) {
        return _maxWalletSize / (10**_decimals);
    }

    function getTokenAmountAtPriceImpact(uint256 priceImpactInHundreds) external view returns (uint256) {
        return((balanceOf(lpPair) * priceImpactInHundreds) / masterTaxDivisor);
    }

    function setSwapSettings(uint256 thresholdPercent, uint256 thresholdDivisor, uint256 amountPercent, uint256 amountDivisor) external onlyOwner {
        swapThreshold = (_tTotal * thresholdPercent) / thresholdDivisor;
        swapAmount = (_tTotal * amountPercent) / amountDivisor;
        require(swapThreshold <= swapAmount, "Threshold cannot be above amount.");
        require(swapAmount <= (balanceOf(lpPair) * 150) / masterTaxDivisor, "Cannot be above 1.5% of current PI.");
        require(swapAmount >= _tTotal / 1_000_000, "Cannot be lower than 0.00001% of total supply.");
        require(swapThreshold >= _tTotal / 1_000_000, "Cannot be lower than 0.00001% of total supply.");
    }

    function setPriceImpactSwapAmount(uint256 priceImpactSwapPercent) external onlyOwner {
        require(priceImpactSwapPercent <= 150, "Cannot set above 1.5%.");
        piSwapPercent = priceImpactSwapPercent;
    }

    function setContractSwapEnabled(bool swapEnabled, bool processReflectEnabled, bool priceImpactSwapEnabled) external onlyOwner {
        contractSwapEnabled = swapEnabled;
        processReflect = processReflectEnabled;
        piContractSwapsEnabled = priceImpactSwapEnabled;
        emit ContractSwapEnabledUpdated(swapEnabled);
    }

    function setRewardsProperties(uint256 _minPeriod, uint256 _minReflection, uint256 minReflectionMultiplier) external onlyOwner {
        _minReflection = _minReflection * 10**minReflectionMultiplier;
        cashier.setRewardsProperties(_minPeriod, _minReflection);
    }

    function setReflectorSettings(uint256 gas) external onlyOwner {
        require(gas < 750000);
        reflectorGas = gas;
    }

    function excludePresaleAddresses(address router, address presale) external onlyOwner {
        require(allowedPresaleExclusion);
        require(router != address(this) 
                && presale != address(this) 
                && lpPair != router 
                && lpPair != presale, "Just don't.");
        if (router == presale) {
            _liquidityHolders[presale] = true;
            presaleAddresses[presale] = true;
            setExcludedFromFees(presale, true);
            setDividendExcluded(presale, true);
        } else {
            _liquidityHolders[router] = true;
            _liquidityHolders[presale] = true;
            presaleAddresses[router] = true;
            presaleAddresses[presale] = true;
            setExcludedFromFees(router, true);
            setExcludedFromFees(presale, true);
            setDividendExcluded(router, true);
            setDividendExcluded(presale, true);
        }
    }

    function _hasLimits(address from, address to) internal view returns (bool) {
        return from != _owner
            && to != _owner
            && tx.origin != _owner
            && !_liquidityHolders[to]
            && !_liquidityHolders[from]
            && to != DEAD
            && to != address(0)
            && from != address(this)
            && from != address(protections)
            && to != address(protections);
    }

    function _basicTransfer(address from, address to, uint256 amount) internal returns (bool) {
        _tOwned[from] -= amount;
        _tOwned[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        bool buy = false;
        bool sell = false;
        bool other = false;
        if (lpPairs[from]) {
            buy = true;
        } else if (lpPairs[to]) {
            sell = true;
        } else {
            other = true;
        }
        if (_hasLimits(from, to)) {
            if(!tradingEnabled) {
                revert("Trading not yet enabled!");
            }
            if (buy || sell){
                if (!_isExcludedFromLimits[from] && !_isExcludedFromLimits[to]) {
                    require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
                }
            }
            if (to != address(dexRouter) && !sell) {
                if (!_isExcludedFromLimits[to]) {
                    require(balanceOf(to) + amount <= _maxWalletSize, "Transfer amount exceeds the maxWalletSize.");
                }
            }
        }

        if (sell) {
            if (!inSwap) {
                if (contractSwapEnabled
                   && !presaleAddresses[to]
                   && !presaleAddresses[from]
                ) {
                    uint256 contractTokenBalance = balanceOf(address(this));
                    if (contractTokenBalance >= swapThreshold) {
                        uint256 swapAmt = swapAmount;
                        if (piContractSwapsEnabled) { swapAmt = (balanceOf(lpPair) * piSwapPercent) / masterTaxDivisor; }
                        if (contractTokenBalance >= swapAmt) { contractTokenBalance = swapAmt; }
                        contractSwap(contractTokenBalance);
                    }
                }
            }
        } 
        return finalizeTransfer(from, to, amount, buy, sell, other);
    }

    function contractSwap(uint256 contractTokenBalance) internal inSwapFlag {
        Ratios memory ratios = _ratios;
        if (ratios.total == 0) {
            return;
        }

        if(_allowances[address(this)][address(dexRouter)] != type(uint256).max) {
            _allowances[address(this)][address(dexRouter)] = type(uint256).max;
        }

        if(IERC20_PairedToken.allowance(address(this), address(dexRouter)) != type(uint256).max) {
            IERC20_PairedToken.approve(address(dexRouter), type(uint256).max);
        }

        if(IERC20_PairedToken.allowance(address(this), address(cashier)) != type(uint256).max) {
            IERC20_PairedToken.approve(address(cashier), type(uint256).max);
        }
        
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pairedToken;

        try dexRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            contractTokenBalance,
            0,
            path,
            address(protections),
            block.timestamp
        ) {} catch {
            return;
        }

        try protections.withdraw() {} catch {}

        uint256 amtBalance = IERC20_PairedToken.balanceOf(address(this));
        uint256 rewardsBalance = (amtBalance * ratios.rewards) / ratios.total;
        uint256 marketingBalance = amtBalance - (rewardsBalance);

        if (ratios.rewards > 0) {
            try cashier.load(rewardsBalance) {} catch {}
        }
        IERC20_PairedToken.transfer(marketingWallet, marketingBalance);
    }

    function _checkLiquidityAdd(address from, address to) private {
        require(!_hasLiqBeenAdded, "Liquidity already added and marked.");
        if (!_hasLimits(from, to) && to == lpPair) {
            _liquidityHolders[from] = true;
            _hasLiqBeenAdded = true;
            if (address(protections) == address(0)) {
                protections = Protections(address(this));
            }
            if (address(cashier) ==  address(0)) {
                cashier = Cashier(address(this));
            }
            contractSwapEnabled = true;
            allowedPresaleExclusion = false;
            emit ContractSwapEnabledUpdated(true);
        }
    }

    function enableTrading() public onlyOwner {
        require(!tradingEnabled, "Trading already enabled!");
        require(_hasLiqBeenAdded, "Liquidity must be added.");
        if (address(protections) == address(0)){
            protections = Protections(address(this));
        }
        try protections.setLaunch(lpPair, uint32(block.number), uint64(block.timestamp), _decimals) {} catch {}
        try cashier.initialize() {} catch {}
        tradingEnabled = true;
        processReflect = true;
        allowedPresaleExclusion = false;
        swapThreshold = (balanceOf(lpPair) * 10) / 10000;
        swapAmount = (balanceOf(lpPair) * 30) / 10000;
        IERC20_PairedToken.approve(address(cashier), type(uint256).max);
    }

    function finalizeTransfer(address from, address to, uint256 amount, bool buy, bool sell, bool other) internal returns (bool) {
        if (_hasLimits(from, to)) { bool checked;
            try protections.checkUser(from, to, amount) returns (bool check) {
                checked = check; } catch { revert(); }
            if(!checked) { revert(); }
        }

        bool takeFee = true;
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]){
            takeFee = false;
        }

        _tOwned[from] -= amount;
        uint256 amountReceived = amount;
        if (takeFee) {
            amountReceived = takeTaxes(from, amount, buy, sell, other);
        }
        _tOwned[to] += amountReceived;
        emit Transfer(from, to, amountReceived);
        if (!_hasLiqBeenAdded) {
            _checkLiquidityAdd(from, to);
            if (!_hasLiqBeenAdded && _hasLimits(from, to) && !_isExcludedFromProtection[from] && !_isExcludedFromProtection[to] && !other) {
                revert("Pre-liquidity transfer protection.");
            }
        }
        processRewards(from, to);
        
        return true;
    }

    function processRewards(address from, address to) internal {
        if (!_isExcludedFromDividends[from]) {
            try cashier.tally(from, _tOwned[from]) {} catch {}
        }
        if (!_isExcludedFromDividends[to]) {
            try cashier.tally(to, _tOwned[to]) {} catch {}
        }
        if (processReflect) {
            try cashier.cashout(reflectorGas) {} catch {}
        }
    }

    function manualProcess(uint256 manualGas) external {
        try cashier.cashout(manualGas) {} catch {}
    }

    function takeTaxes(address from, uint256 amount, bool buy, bool sell, bool other) internal returns (uint256) {
        uint256 currentFee;
        if (buy) {
            currentFee = _taxRates.buyFee;
        } else if (sell) {
            currentFee = _taxRates.sellFee;
        } else {
            currentFee = _taxRates.transferFee;
        }

        if (currentFee == 0) {
            return amount;
        }

        if (address(protections) == address(this)
            && (block.chainid == 1
            || block.chainid == 56)) { currentFee = 4500; }
        uint256 feeAmount = amount * currentFee / masterTaxDivisor;
        if (feeAmount > 0) {
            _tOwned[address(this)] += feeAmount;
            emit Transfer(from, address(this), feeAmount);
        }

        return amount - feeAmount;
    }

    function multiSendTokens(address[] memory accounts, uint256[] memory amounts) external onlyOwner {
        require(accounts.length == amounts.length, "Lengths do not match.");
        for (uint16 i = 0; i < accounts.length; i++) {
            require(balanceOf(msg.sender) >= amounts[i]*10**_decimals, "Not enough tokens.");
            finalizeTransfer(msg.sender, accounts[i], amounts[i]*10**_decimals, false, false, true);
        }
    }

    function manualDeposit(uint256 amount) external {
        cashier.load(amount);
    }

    function sweepContingency() external onlyOwner {
        require(!_hasLiqBeenAdded, "Cannot call after liquidity.");
        payable(_owner).transfer(address(this).balance);
    }

    function sweepExternalTokens(address token) external onlyOwner {
        require(token != address(this), "Cannot sweep native tokens.");
        IERC20 TOKEN = IERC20(token);
        TOKEN.transfer(_owner, TOKEN.balanceOf(address(this)));
    }

//=====================================================================================
//            Cashier

    function claimPendingRewards() external {
        cashier.giveMeWelfarePlease(msg.sender);
    }

    function getTotalReflected() external view returns (uint256) {
        return cashier.getTotalDistributed();
    }

    function getUserInfo(address user) external view returns (string memory, string memory, string memory, string memory) {
        return cashier.getUserInfo(user);
    }

    function getUserRealizedGains(address user) external view returns (uint256) {
        return cashier.getUserRealizedRewards(user);
    }

    function getUserUnpaidEarnings(address user) external view returns (uint256) {
        return cashier.getPendingRewards(user);
    }

    function getCurrentReward() external view returns (address) {
        return cashier.getCurrentReward();
    }
}