/**
 *Submitted for verification at BscScan.com on 2022-05-16
*/

// File: contracts/BNBPROTOCOL.sol

pragma solidity ^0.8.10;


library SafeMath {
    function tryAdd(uint256 a, uint256 b)
    internal
    pure
    returns (bool, uint256)
    {
    unchecked {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }
    }

    function trySub(uint256 a, uint256 b)
    internal
    pure
    returns (bool, uint256)
    {
    unchecked {
        if (b > a) return (false, 0);
        return (true, a - b);
    }
    }

    function tryMul(uint256 a, uint256 b)
    internal
    pure
    returns (bool, uint256)
    {
    unchecked {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }
    }

    function tryDiv(uint256 a, uint256 b)
    internal
    pure
    returns (bool, uint256)
    {
    unchecked {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }
    }

    function tryMod(uint256 a, uint256 b)
    internal
    pure
    returns (bool, uint256)
    {
    unchecked {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
    unchecked {
        require(b <= a, errorMessage);
        return a - b;
    }
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
    unchecked {
        require(b > 0, errorMessage);
        return a / b;
    }
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
    unchecked {
        require(b > 0, errorMessage);
        return a % b;
    }
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
    external
    returns (address pair);
}

interface IDexRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
    external
    payable
    returns (
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IERC20Extended {
    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
    external
    returns (bool);

    function allowance(address _owner, address spender)
    external
    view
    returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IStackedStaking {
    function stakedTokens(address user) external returns (uint256);
}

abstract contract Auth {
    address internal owner;
    mapping(address => bool) internal authorizations;

    constructor(address _owner) {
        owner = _owner;
        authorizations[_owner] = true;
    }

    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER");
        _;
    }

    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED");
        _;
    }

    function authorize(address adr) public onlyOwner {
        authorizations[adr] = true;
    }

    function unauthorize(address adr) public onlyOwner {
        authorizations[adr] = false;
    }

    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }

    function transferOwnership(address payable adr) public onlyOwner {
        owner = adr;
        authorizations[adr] = true;
        emit OwnershipTransferred(adr);
    }

    event OwnershipTransferred(address owner);
}

interface IDividendDistributor {
    function setDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution
    ) external;

    function setShare(address shareholder, uint256 amount) external;

    function deposit() external payable;

    function process(uint256 gas) external;

    function claimDividend(address _user) external;

    function getPaidEarnings(address shareholder)
    external
    view
    returns (uint256);

    function getUnpaidEarnings(address shareholder)
    external
    view
    returns (uint256);

    function totalDistributed() external view returns (uint256);
}

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;

    address public _token;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    IERC20Extended public rewardToken =
    IERC20Extended(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IDexRouter public router;

    address[] public shareholders;
    mapping(address => uint256) public shareholderIndexes;
    mapping(address => uint256) public shareholderClaims;

    mapping(address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10**36;

    uint256 public minPeriod = 1 hours;
    uint256 public minDistribution = 1 * (10**rewardToken.decimals());

    uint256 currentIndex;

    bool initialized;
    modifier initializer() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token);
        _;
    }

    constructor(address router_) {
        _token = msg.sender;
        router = IDexRouter(router_);
    }

    receive() external payable {
        deposit();
    }

    function setDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution
    ) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    function setShare(address shareholder, uint256 amount)
    external
    override
    onlyToken
    {
        if (shares[shareholder].amount > 0) {
            distributeDividend(shareholder);
        }

        if (amount > 0 && shares[shareholder].amount == 0) {
            addShareholder(shareholder);
        } else if (amount == 0 && shares[shareholder].amount > 0) {
            removeShareholder(shareholder);
        }

        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(
            shares[shareholder].amount
        );
    }

    function deposit() public payable override {
        uint256 balanceBefore = rewardToken.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(rewardToken);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
        value: msg.value
        }(0, path, address(this), block.timestamp);

        uint256 amount = rewardToken.balanceOf(address(this)).sub(
            balanceBefore
        );

        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(
            dividendsPerShareAccuracyFactor.mul(amount).div(totalShares)
        );
    }

    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = shareholders.length;

        if (shareholderCount == 0) {
            return;
        }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }

            if (shouldDistribute(shareholders[currentIndex])) {
                distributeDividend(shareholders[currentIndex]);
            }

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    function shouldDistribute(address shareholder)
    internal
    view
    returns (bool)
    {
        return
        shareholderClaims[shareholder] + minPeriod < block.timestamp &&
        getUnpaidEarnings(shareholder) > minDistribution;
    }

    function distributeDividend(address shareholder) internal {
        if (shares[shareholder].amount == 0) {
            return;
        }

        uint256 amount = getUnpaidEarnings(shareholder);
        if (amount > 0) {
            totalDistributed = totalDistributed.add(amount);
            rewardToken.transfer(shareholder, amount);
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder]
            .totalRealised
            .add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(
                shares[shareholder].amount
            );
        }
    }

    function claimDividend(address _user) external {
        distributeDividend(_user);
    }

    function getPaidEarnings(address shareholder)
    public
    view
    returns (uint256)
    {
        return shares[shareholder].totalRealised;
    }

    function getUnpaidEarnings(address shareholder)
    public
    view
    returns (uint256)
    {
        if (shares[shareholder].amount == 0) {
            return 0;
        }

        uint256 shareholderTotalDividends = getCumulativeDividends(
            shares[shareholder].amount
        );
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if (shareholderTotalDividends <= shareholderTotalExcluded) {
            return 0;
        }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function getCumulativeDividends(uint256 share)
    internal
    view
    returns (uint256)
    {
        return
        share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[
        shareholders.length - 1
        ];
        shareholderIndexes[
        shareholders[shareholders.length - 1]
        ] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}

contract BNBPROTOCOL is IERC20Extended, Auth {
    using SafeMath for uint256;

    string private constant _name = "BNBPROTOCOL";
    string private constant _symbol = "BNBPROTOCOL";
    uint8 private constant _decimals = 18;
    uint256 private constant _totalSupply =
    20_000_000_000 * 10**_decimals;

    address public rewardToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // BUSD
    address public constant DEAD = address(0xdead);
    address public constant ZERO = address(0);
    address public pair;
    address public autoLiquidityReceiver = 0x37B81a831B9079E327F7638D06e5EdfDf9A768D8; // address to receive LP tokens from liquidity add from fee
    address public marketingFeeReceiver = 0x7441d601FfD9408e21Aa11a2b13f8f83c4D75507; // address to receive marketing fee
    address public stakingFeeReceiver = 0xa1E6F445d0ab977Eb7D28FA91d10B74E47503eD5; // address to receive staking fee

    // fees info
    uint256 public liquidityFee = 200;
    uint256 public buybackFee = 100;
    uint256 public reflectionFee = 1500;
    uint256 public marketingFee = 100;
    uint256 public stakingFee = 100;
    uint256 public totalFee = 2000;
    uint256 public feeDenominator = 10000;
    uint256 public sellMultiplier = 1;

    // Determines whether to add liquidity fee to liquidity, target liquidity is 25%
    uint256 public targetLiquidity = 25;
    uint256 public targetLiquidityDenominator = 100;

    uint256 public distributorGas = 500000;
    uint256 public antiWhaleSellLimitDenominator = 1000;
    uint256 public swapThreshold = _totalSupply / 20000;
    uint256 public startBlock;
    uint256 private deadBlocks;
    uint256 private sniperFee;

    bool public sellMultiplierEnabled;
    bool public swapEnabled = true;
    bool public enableStaking;
    bool public tradingEnabled;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isFeeExempt;
    mapping(address => bool) public isDividendExempt;
    mapping(address => bool) public canTransferBeforeTradingIsEnabled;
    mapping(address => bool) public excludedFromSellLimit;

    DividendDistributor public distributor;
    IStackedStaking public stake;
    IDexRouter public router;

    event AutoLiquify(uint256 amountBNB, uint256 amountBOG);

    bool inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }


    constructor()
    payable
    Auth(msg.sender)
    {

        router = IDexRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );
        distributor = new DividendDistributor(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        isFeeExempt[msg.sender] = true;
        isFeeExempt[marketingFeeReceiver] = true;
        isFeeExempt[autoLiquidityReceiver] = true;
        isFeeExempt[stakingFeeReceiver] = true;

        isDividendExempt[msg.sender] = true;
        isDividendExempt[autoLiquidityReceiver] = true;
        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[DEAD] = true;
        isDividendExempt[ZERO] = true;

        canTransferBeforeTradingIsEnabled[msg.sender] = true;
        canTransferBeforeTradingIsEnabled[marketingFeeReceiver] = true;

        _allowances[address(this)][address(router)] = _totalSupply;
        _allowances[address(this)][address(pair)] = _totalSupply;

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable {}


    // Anti-Bot
    function enableTrading(
        uint _deadBlocks,
        uint _sniperFee
    )
    external
    authorized
    {
        tradingEnabled = true;
        startBlock = block.number;
        deadBlocks = _deadBlocks;
        sniperFee = _sniperFee; // in basis points, base 10000
    }


    // Whitelist pinksale
    function setPresale(
        address presaleAddress
    )
    external
    authorized
    {
        isFeeExempt[presaleAddress] = true;
        isDividendExempt[presaleAddress] = true;
        canTransferBeforeTradingIsEnabled[presaleAddress] = true;
        excludedFromSellLimit[presaleAddress] = true;
    }


    // Standard ERC-20 Functions
    function totalSupply()
    external
    pure
    override
    returns (uint256)
    {
        return _totalSupply;
    }


    function decimals()
    external
    pure
    override
    returns (uint8)
    {
        return _decimals;
    }


    function symbol()
    external
    pure
    override
    returns (string memory)
    {
        return _symbol;
    }


    function name()
    external
    pure
    override
    returns (string memory)
    {
        return _name;
    }


    function balanceOf(
        address account
    )
    public
    view
    override
    returns (uint256)
    {
        return _balances[account];
    }


    function allowance(
        address holder,
        address spender
    )
    external
    view
    override
    returns (uint256)
    {
        return _allowances[holder][spender];
    }


    function approve(
        address spender,
        uint256 amount
    )
    public
    override
    returns (bool)
    {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }


    function approveMax(
        address spender
    )
    external
    returns (bool)
    {
        return approve(spender, _totalSupply);
    }


    function transfer(
        address recipient,
        uint256 amount
    )
    external
    override
    returns (bool)
    {
        return _transferFrom(msg.sender, recipient, amount);
    }


    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
    external
    override
    returns (bool)
    {
        if (_allowances[sender][msg.sender] != _totalSupply) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender]
            .sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }


    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
    internal
    returns (bool)
    {

        if (!tradingEnabled) {
            require(canTransferBeforeTradingIsEnabled[sender], "You cannot transfer before trading is enabled");
        }

        if (enableStaking) {
            require(
                _balances[sender].sub(amount) >= stake.stakedTokens(sender),
                "Can not send staked token"
            );
        }

        if (recipient == pair && sender != owner && !excludedFromSellLimit[sender]) {
            uint256 sellLimit = getAntiWhaleSellLimit();
            require(amount <= sellLimit, "Antiwhale limit exceeded");
        }

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (shouldSwapBack()) {
            swapBack();
        }

        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );

        uint256 amountReceived;
        if (block.number < startBlock.add(deadBlocks)) {
            amountReceived = shouldTakeFee(sender, recipient)
            ? takeSniperFee(sender, amount)
            : amount;
        }
        else {
            amountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, amount)
            : amount;
        }

        _balances[recipient] = _balances[recipient].add(amountReceived);

        if (!isDividendExempt[sender]) {
            try distributor.setShare(sender, _balances[sender]) {} catch {}
        }
        if (!isDividendExempt[recipient]) {
            try
            distributor.setShare(recipient, _balances[recipient])
            {} catch {}
        }

        try distributor.process(distributorGas) {} catch {}

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }


    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    )
    internal
    returns (bool)
    {
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }


    function shouldTakeFee(
        address sender,
        address recipient
    )
    internal
    view
    returns (bool)
    {
        if (isFeeExempt[sender] || isFeeExempt[recipient]) {
            return false;
        }
        else if (sender != pair && recipient != pair) {
            return false;
        }
        return true;
    }


    function getTotalFee(
        bool selling
    )
    public
    view
    returns (uint256)
    {
        if (selling) {
            return getMultipliedFee();
        }
        return totalFee;
    }


    function getMultipliedFee()
    public
    view
    returns (uint256)
    {
        if (sellMultiplierEnabled) {
            return totalFee.mul(sellMultiplier);
        }
        return totalFee;
    }


    function takeFee(
        address sender,
        address receiver,
        uint256 amount
    )
    internal
    returns (uint256)
    {
        uint256 feeAmount = amount.mul(getTotalFee(receiver == pair)).div(
            feeDenominator
        );

        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);

        return amount.sub(feeAmount);
    }


    function takeSniperFee(
        address sender,
        uint256 amount
    )
    internal
    returns (uint256)
    {
        uint256 feeAmount = amount.mul(sniperFee).div(
            feeDenominator
        );

        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);

        return amount.sub(feeAmount);
    }


    function shouldSwapBack()
    internal
    view
    returns (bool)
    {
        return
        msg.sender != pair &&
        !inSwap &&
        swapEnabled &&
        _balances[address(this)] >= swapThreshold;
    }


    function swapBack()
    internal
    swapping
    {
        uint256 amountTokenStaking = swapThreshold.mul(stakingFee).div(
            totalFee
        );
        uint256 dynamicLiquidityFee = isOverLiquified(
            targetLiquidity,
            targetLiquidityDenominator
        )
        ? 0
        : liquidityFee;
        uint256 amountToLiquify = swapThreshold
        .mul(dynamicLiquidityFee)
        .div(totalFee)
        .div(2);
        uint256 amountToSwap = swapThreshold.sub(amountToLiquify).sub(
            amountTokenStaking
        );

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        uint256 balanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountBNB = address(this).balance.sub(balanceBefore);

        uint256 totalBNBFee = totalFee.sub(dynamicLiquidityFee.div(2)).sub(
            stakingFee
        );

        uint256 amountBNBLiquidity = amountBNB
        .mul(dynamicLiquidityFee)
        .div(totalBNBFee)
        .div(2);
        uint256 amountBNBReflection = amountBNB.mul(reflectionFee).div(
            totalBNBFee
        );
        uint256 amountBNBMarketing = amountBNB.mul(marketingFee).div(
            totalBNBFee
        );

        try distributor.deposit{value: amountBNBReflection}() {} catch {}
        payable(marketingFeeReceiver).transfer(amountBNBMarketing);
        _balances[stakingFeeReceiver] = _balances[stakingFeeReceiver].add(
            amountTokenStaking
        );

        if (amountToLiquify > 0) {
            router.addLiquidityETH{value: amountBNBLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );
            emit AutoLiquify(amountBNBLiquidity, amountToLiquify);
        }
    }


    // Buyback and burn
    function triggerManualBuyback(
        uint256 amount
    )
    external
    authorized
    {
        buyTokens(amount, DEAD);
    }


    function buyTokens(
        uint256 amount,
        address to
    )
    internal
    swapping
    {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
        value: amount
        }(0, path, to, block.timestamp);
    }


    function claimDividend()
    external
    {
        distributor.claimDividend(msg.sender);
    }


    function getPaidDividend(
        address shareholder
    )
    public
    view
    returns (uint256)
    {
        return distributor.getPaidEarnings(shareholder);
    }


    function getUnpaidDividend(
        address shareholder
    )
    external
    view
    returns (uint256)
    {
        return distributor.getUnpaidEarnings(shareholder);
    }


    function getTotalDistributedDividend()
    external
    view
    returns (uint256)
    {
        return distributor.totalDistributed();
    }


    function setRoute(
        address _router,
        address _pair
    )
    external
    authorized
    {
        router = IDexRouter(_router);
        pair = _pair;
    }


    function setIsDividendExempt(
        address holder,
        bool exempt
    )
    external
    authorized
    {
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;
        if (exempt) {
            distributor.setShare(holder, 0);
        } else {
            distributor.setShare(holder, _balances[holder]);
        }
    }


    function setIsFeeExempt(
        address holder,
        bool exempt
    )
    external
    authorized
    {
        isFeeExempt[holder] = exempt;
    }


    function setExcludedFromSellLimit(
        address _address,
        bool _value
    )
    external
    authorized
    {
        excludedFromSellLimit[_address] = _value;
    }


    function setFees(
        uint256 _liquidityFee,
        uint256 _buybackFee,
        uint256 _reflectionFee,
        uint256 _marketingFee,
        uint256 _stakingFee,
        uint256 _feeDenominator
    )
    external
    authorized
    {
        liquidityFee = _liquidityFee;
        buybackFee = _buybackFee;
        reflectionFee = _reflectionFee;
        marketingFee = _marketingFee;
        stakingFee = _stakingFee;
        totalFee = _liquidityFee
        .add(_buybackFee)
        .add(_reflectionFee)
        .add(_marketingFee)
        .add(_stakingFee);
        feeDenominator = _feeDenominator;
        require(
            totalFee < feeDenominator / 4,
            "Total fee should not be greater than 1/4 of fee denominator"
        );
    }


    function setFeeReceivers(
        address _autoLiquidityReceiver,
        address _marketingFeeReceiver,
        address _stakingFeeReceiver
    )
    external
    authorized
    {
        autoLiquidityReceiver = _autoLiquidityReceiver;
        marketingFeeReceiver = _marketingFeeReceiver;
        stakingFeeReceiver = _stakingFeeReceiver;
    }


    function setStakeAddress(
        address _staking,
        bool _enable
    )
    external
    authorized
    {
        stake = IStackedStaking(_staking);
        enableStaking = _enable;
    }


    function setSwapBackSettings(
        bool _enabled,
        uint256 _amount
    )
    external
    authorized
    {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }


    function setTargetLiquidity(
        uint256 _target,
        uint256 _denominator
    )
    external
    authorized
    {
        targetLiquidity = _target;
        targetLiquidityDenominator = _denominator;
    }


    function setDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution
    )
    external
    authorized
    {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution);
    }


    function setDistributorSettings(
        uint256 gas
    )
    external
    authorized
    {
        require(gas < 750000, "Gas must be lower than 750000");
        distributorGas = gas;
    }


    function setAntiWhaleSellLimitDenominator(
        uint256 newDenominator
    )
    external
    authorized
    {
        require(
            newDenominator <= 200000,
            "amount must be greater than 0.002% of circulating supply supply"
        );
        antiWhaleSellLimitDenominator = newDenominator;
    }


    function getCirculatingSupply()
    public
    view
    returns (uint256)
    {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }

    function getAntiWhaleSellLimit()
    public
    view
    returns (uint256)
    {
        return getCirculatingSupply()/antiWhaleSellLimitDenominator;
    }


    // Determines what percent of market cap is backed
    function getLiquidityBacking(
        uint256 accuracy
    )
    public
    view
    returns (uint256)
    {
        return accuracy.mul(balanceOf(pair).mul(2)).div(getCirculatingSupply());
    }


    // Determines if target liquidity is met
    function isOverLiquified(
        uint256 target,
        uint256 accuracy
    )
    public
    view
    returns (bool)
    {
        return getLiquidityBacking(accuracy) > target;
    }


    function setSellMultiplier(
        bool _enabled,
        uint256 _multiplier
    )
    external
    authorized
    {
        require(_multiplier <= 5, "Sell Multiplier Cannot be more than 5x");
        sellMultiplierEnabled = _enabled;
        sellMultiplier = _multiplier;
    }
}