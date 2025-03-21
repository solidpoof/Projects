// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract ParamountMinerBUSD is Ownable{
    using SafeMath for uint256;

    IERC20 public token = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); //** Main
    // IERC20 public token = IERC20(0xA63a11721792915Fe0acEf709293f95e483d7d23); //** Test
    address payable public dev;
    address payable public market;

    uint256 public ORES_TO_HIRE_1CRAFT = 1728000;
    uint256 public REFERRAL = 30;
    uint256 public PERCENTS_DIVIDER = 1000;
    uint256 public DEV_TAX = 15;
    uint256 public MARKET_TAX = 15;
    uint256 public MARKET_ORES_DIVISOR = 2;

    uint256 public MIN_DEPOSIT_LIMIT = 1 ether;
    uint256 public MAX_WITHDRAW_LIMIT = 1000 ether;
    uint256[5] public ROI_MAP = [50_000 ether, 100_000 ether, 500_000 ether, 1_000_000 ether, 5_000_000 ether];

	uint256 public COMPOUND_BONUS = 5;
	uint256 public COMPOUND_MAX_TIMES = 10;
    uint256 public COMPOUND_DURATION = 12 * 60 * 60;
	uint256 public PROOF_OF_LIFE = 48 * 60 * 60;
    uint256 public WITHDRAWAL_TAX = 700;
    uint256 public COMPOUND_FOR_NO_TAX_WITHDRAWAL = 10;

    uint256 public totalStaked;
    uint256 public totalCrafts;
    uint256 public totalDeposits;
    uint256 public totalCompound;
    uint256 public totalRefBonus;
    uint256 public totalWithdrawn;

    uint256 public marketOres = 144000000000;
    uint256 PSN = 10000;
    uint256 PSNH = 5000;
    bool public contractStarted;

    struct User {
        uint256 initialDeposit;
        uint256 userDeposit;
        uint256 crafts;
        uint256 claimedOres;
        uint256 lastHatch;
        address referrer;
        uint256 referralsCount;
        uint256 referralRewards;
        uint256 totalWithdrawn;
        uint256 dailyCompoundBonus;
        uint256 craftsCompoundCount;
        uint256 lastWithdrawTime;
    }

    mapping(address => User) public users;

    constructor(address payable _dev, address payable _market) {
		require(!isContract(_dev) && !isContract(_market));
        dev = _dev;
        market = _market;
    }

	function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function startJourney() public onlyOwner{
    	require(!contractStarted, "Already started");
    	contractStarted = true;
    }

    function buyMoreSpaceShuttles() public {
        require(contractStarted, "Contract not yet Started.");
        User storage user = users[msg.sender];
        require(block.timestamp.sub(user.lastHatch) >= COMPOUND_DURATION,"Wait for next compound");
        compound(true);
    }

    function compound(bool isCompound) internal {
        
        User storage user = users[msg.sender];

        uint256 oresUsed = getMyOres(msg.sender);
        uint256 oresForCompound = oresUsed;

        if(isCompound) {
            uint256 dailyCompoundBonus = getDailyCompoundBonus(msg.sender, oresForCompound);
            oresForCompound = oresForCompound.add(dailyCompoundBonus);
            uint256 oresUsedValue = calculateOresSell(oresForCompound);
            user.userDeposit = user.userDeposit.add(oresUsedValue);
            totalCompound = totalCompound.add(oresUsedValue);
        } 

        if(user.dailyCompoundBonus < COMPOUND_MAX_TIMES) {
            user.dailyCompoundBonus = user.dailyCompoundBonus.add(1);
        }
        //add compoundCount for monitoring purposes.
        user.craftsCompoundCount = user.craftsCompoundCount .add(1);
        user.crafts = user.crafts.add(oresForCompound.div(ORES_TO_HIRE_1CRAFT));
        totalCrafts = totalCrafts.add(oresForCompound.div(ORES_TO_HIRE_1CRAFT));
        user.claimedOres = 0;
        user.lastHatch = block.timestamp;

        marketOres = marketOres.add(oresUsed.div(MARKET_ORES_DIVISOR));
    }

    function sellOres() public{
        require(contractStarted, "Contract not yet Started.");

        User storage user = users[msg.sender];
        uint256 hasOres = getMyOres(msg.sender);
        uint256 oresValue = calculateOresSell(hasOres);
        
        /** 
            if user compound < to mandatory compound days**/
        if(user.dailyCompoundBonus < COMPOUND_FOR_NO_TAX_WITHDRAWAL){
            //daily compound bonus count will not reset and oresValue will be deducted with x% feedback tax.
            oresValue = oresValue.sub(oresValue.mul(WITHDRAWAL_TAX).div(PERCENTS_DIVIDER));
        }else{
            //set daily compound bonus count to 0 and oresValue will remain without deductions
             user.dailyCompoundBonus = 0;   
             user.craftsCompoundCount = 0;  
        }
        
        user.lastWithdrawTime = block.timestamp;
        user.claimedOres = 0;  
        user.lastHatch = block.timestamp;
        marketOres = marketOres.add(hasOres.div(MARKET_ORES_DIVISOR));
        
        // Antiwhale limit
        if(oresValue > MAX_WITHDRAW_LIMIT){
            buy(msg.sender, address(0), oresValue.sub(MAX_WITHDRAW_LIMIT));
            oresValue = MAX_WITHDRAW_LIMIT;
        }
        if(oresValue > getBalance()) {
            buy(msg.sender, address(0), oresValue.sub(getBalance()));
            oresValue = getBalance();
        }

        uint256 oresPayout = oresValue.sub(takeFees(oresValue));
        token.transfer(msg.sender, oresPayout);
        user.totalWithdrawn = user.totalWithdrawn.add(oresPayout);
        totalWithdrawn = totalWithdrawn.add(oresPayout);
    }

    /** Deposit **/
    function buySpaceShuttles(address ref, uint256 amount) public {
        require(contractStarted, "Contract not yet Started.");
        require(amount >= MIN_DEPOSIT_LIMIT, "Less than min limit");
        token.transferFrom(msg.sender, address(this), amount);
        buy(msg.sender, ref, amount);
    }
     
    function buy(address _user, address ref, uint256 amount) internal {
        User storage user = users[_user];
        uint256 oresBought = calculateOresBuy(amount, getBalance().sub(amount));
        user.userDeposit = user.userDeposit.add(amount);
        user.initialDeposit = user.initialDeposit.add(amount);
        user.claimedOres = user.claimedOres.add(oresBought);

        if (user.referrer == address(0)) {
            if (ref != _user) {
                user.referrer = ref;
            }

            address upline1 = user.referrer;
            if (upline1 != address(0)) {
                users[upline1].referralsCount = users[upline1].referralsCount.add(1);
            }
        }
                
        if (user.referrer != address(0)) {
            address upline = user.referrer;
            if (upline != address(0)) {
                uint256 refRewards = amount.mul(REFERRAL).div(PERCENTS_DIVIDER);
                token.transfer(upline, refRewards);
                users[upline].referralRewards = users[upline].referralRewards.add(refRewards);
                totalRefBonus = totalRefBonus.add(refRewards);
            }
        }

        uint256 oresPayout = takeFees(amount);
        totalStaked = totalStaked.add(amount.sub(oresPayout));
        totalDeposits = totalDeposits.add(1);
        compound(false);

        if(getBalance() < ROI_MAP[0]){
            ORES_TO_HIRE_1CRAFT = 1728000;
        } else if(getBalance() >= ROI_MAP[0] && getBalance() < ROI_MAP[1]){
            ORES_TO_HIRE_1CRAFT = 1584000;
        } else if(getBalance() >= ROI_MAP[1] && getBalance() < ROI_MAP[2]){
            ORES_TO_HIRE_1CRAFT = 1440000;
        } else if(getBalance() >= ROI_MAP[2] && getBalance() < ROI_MAP[3]){
            ORES_TO_HIRE_1CRAFT = 1320000;
        }  else if(getBalance() >= ROI_MAP[3] && getBalance() < ROI_MAP[4]){
            ORES_TO_HIRE_1CRAFT = 1200000;
        }  else if(getBalance() >= ROI_MAP[4]){
            ORES_TO_HIRE_1CRAFT = 1140000;
        }
    }

    function takeFees(uint256 oresValue) internal returns(uint256){
        uint256 tax = oresValue.mul(DEV_TAX).div(PERCENTS_DIVIDER);
        uint256 marketing = oresValue.mul(MARKET_TAX).div(PERCENTS_DIVIDER);
        token.transfer(dev, tax);
        token.transfer(market, marketing);
        return marketing.add(tax);
    }

    function getDailyCompoundBonus(address _adr, uint256 amount) public view returns(uint256){
        if(users[_adr].dailyCompoundBonus == 0) {
            return 0;
        } else {
            uint256 totalBonus = users[_adr].dailyCompoundBonus.mul(COMPOUND_BONUS); 
            uint256 result = amount.mul(totalBonus).div(PERCENTS_DIVIDER);
            return result;
        }
    }

    function getUserInfo(address _adr) public view returns(uint256 _initialDeposit, uint256 _userDeposit, uint256 _crafts,
     uint256 _claimedOres, uint256 _lastHatch, address _referrer, uint256 _referrals,
	 uint256 _totalWithdrawn, uint256 _referralRewards, uint256 _dailyCompoundBonus, uint256 _craftsCompoundCount, uint256 _lastWithdrawTime) {
         _initialDeposit = users[_adr].initialDeposit;
         _userDeposit = users[_adr].userDeposit;
         _crafts = users[_adr].crafts;
         _claimedOres = users[_adr].claimedOres;
         _lastHatch = users[_adr].lastHatch;
         _referrer = users[_adr].referrer;
         _referrals = users[_adr].referralsCount;
         _totalWithdrawn = users[_adr].totalWithdrawn;
         _referralRewards = users[_adr].referralRewards;
         _dailyCompoundBonus = users[_adr].dailyCompoundBonus;
         _craftsCompoundCount = users[_adr].craftsCompoundCount;
         _lastWithdrawTime = users[_adr].lastWithdrawTime;
	}

    function getBalance() public view returns(uint256){
        return token.balanceOf(address(this));
    }

    function getAvailableEarnings(address _adr) public view returns(uint256) {
        uint256 userOres = users[_adr].claimedOres.add(getOresSinceLastHatch(_adr));
        return calculateOresSell(userOres);
    }

    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256){
        return SafeMath.div(
                SafeMath.mul(PSN, bs), 
                    SafeMath.add(PSNH, 
                        SafeMath.div(
                            SafeMath.add(
                                SafeMath.mul(PSN, rs), 
                                    SafeMath.mul(PSNH, rt)), 
                                        rt)));
    }

    function calculateOresSell(uint256 ores) public view returns(uint256){
        return calculateTrade(ores, marketOres, getBalance());
    }

    function calculateOresBuy(uint256 amount,uint256 contractBalance) public view returns(uint256){
        return calculateTrade(amount, contractBalance, marketOres);
    }

    function calculateOresBuySimple(uint256 amount) public view returns(uint256){
        return calculateOresBuy(amount, getBalance());
    }

    /** How many crafts and Ores per day user will recieve based on deposit amount **/
    function getOresYield(uint256 amount) public view returns(uint256,uint256) {
        uint256 oresAmount = calculateOresBuy(amount , getBalance().add(amount).sub(amount));
        uint256 crafts = oresAmount.div(ORES_TO_HIRE_1CRAFT);
        uint256 day = 1 days;
        uint256 oresPerDay = day.mul(crafts);
        uint256 earningsPerDay = calculateOresSellForYield(oresPerDay, amount);
        return(crafts, earningsPerDay);
    }

    function calculateOresSellForYield(uint256 ores,uint256 amount) public view returns(uint256){
        return calculateTrade(ores,marketOres, getBalance().add(amount));
    }

    function getSiteInfo() public view returns (uint256 _totalStaked, uint256 _totalCrafts, uint256 _totalDeposits, uint256 _totalCompound, uint256 _totalRefBonus) {
        return (totalStaked, totalCrafts, totalDeposits, totalCompound, totalRefBonus);
    }

    function getMyCrafts(address userAddress) public view returns(uint256){
        return users[userAddress].crafts;
    }

    function getMyOres(address userAddress) public view returns(uint256){
        return users[userAddress].claimedOres.add(getOresSinceLastHatch(userAddress));
    }

    function getOresSinceLastHatch(address adr) public view returns(uint256){
        uint256 secondsSinceLastHatch = block.timestamp.sub(users[adr].lastHatch);
        uint256 cutoffTime = min(secondsSinceLastHatch, PROOF_OF_LIFE);
        uint256 secondsPassed = min(ORES_TO_HIRE_1CRAFT, cutoffTime);
        return secondsPassed.mul(users[adr].crafts);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function PRC_MARKET_ORES_DIVISOR(uint256 value) external onlyOwner {
        require(value <= 50);
        MARKET_ORES_DIVISOR = value;
    }

    function SET_WITHDRAWAL_TAX(uint256 value) external onlyOwner {
        require(value <= 900);
        WITHDRAWAL_TAX = value;
    }

    function BONUS_DAILY_COMPOUND(uint256 value) external onlyOwner {
        require(value >= 1 && value <= 30);
        COMPOUND_BONUS = value;
    }

    function BONUS_DAILY_COMPOUND_MAX_TIMES(uint256 value) external onlyOwner {
        require(value <= 30);
        COMPOUND_MAX_TIMES = value;
    }

    function BONUS_COMPOUND_DURATION(uint256 value) external onlyOwner {
        require(value <= 24);
        COMPOUND_DURATION = value * 60 * 60;
    }

    function SET_PROOF_OF_LIFE(uint256 value) external onlyOwner {
        require(value >= 24);
        PROOF_OF_LIFE = value * 60 * 60;
    }

    function SET_MAX_WITHDRAW_LIMIT(uint256 value) external onlyOwner {
        require(value >= 500);
        MAX_WITHDRAW_LIMIT = value * 1 ether;
    }

    function SET_MIN_DEPOSIT_LIMIT(uint256 value) external onlyOwner {
        require(value <= 10);
        MIN_DEPOSIT_LIMIT = value * 1 ether;
    }
    
    function SET_COMPOUND_FOR_NO_TAX_WITHDRAWAL(uint256 value) external onlyOwner {
        require(value <= 12);
        COMPOUND_FOR_NO_TAX_WITHDRAWAL = value;
    }

    function UPDATE_ROI_MAP1(uint256 value) external onlyOwner {
        require(value <= 100_000);
        ROI_MAP[0] = value * 1 ether;
    }

    function UPDATE_ROI_MAP2(uint256 value) external onlyOwner {
        require(value <= 500_000);
        ROI_MAP[1] = value * 1 ether;
    }

    function UPDATE_ROI_MAP3(uint256 value) external onlyOwner {
        require(value <= 1_000_000);
        ROI_MAP[2] = value * 1 ether;
    }

    function UPDATE_ROI_MAP4(uint256 value) external onlyOwner {
        require(value <= 5_000_000);
        ROI_MAP[3] = value * 1 ether;
    }

    function UPDATE_ROI_MAP5(uint256 value) external onlyOwner {
        require(value <= 10_000_000);
        ROI_MAP[4] = value * 1 ether;
    }
}

library SafeMath {

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}