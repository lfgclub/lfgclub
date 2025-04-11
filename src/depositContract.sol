/*                                                         
 *   :**-                                     :=*+:           
 *   +%%[))<=        :-+><][])*+=-:        =<])}@@=           
 *  :<@@@}*+<})*<][#@@@@@@@@@@@@@@@%#[)>*]#<+>#@@@*           
 *  :)@@@@@#]%@@@@@@@@@@@@@@@@@@@@@@@@@@@@#]%@@@@@>           
 *  -]@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@<           
 *  -]@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@<           
 *  :)@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@>           
 *  :>@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+           
 *   *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+           
 *  :<@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@<           
 *  :)@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@<           
 *  -[@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@<           
 *  -[@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@}:          
 *  :=+>#@@@@#[<)[[[)<[@@@@%%@@@#))]}[)<]#@@@@@@@@@}=         
 *   =))#%]*<[[<)#@@@@@]<)[#})]<><)@@@@@@#))[@@@@@@@@[+       
 *    =]):++@< :)@@@@@@@@%][]#@: -%@@@@@@@@][@@@@@@@@@@#*:    
 *   =<=*#@[]= +%@@@@@@@@[<@@>}: <@@@@@@@@@=@@@}}@@@@@@@@%]+: 
 *  :+-)@@@#*<:>@@@@@@@@%[}@@+}: @@@@@@@@@@>@@@%>-])]#@@@@@@[:
 *   :)@@@@@*[-<@@@@@@@@[: += <> @@@@@@@@@*#@@@@@*:           
 *   *%@@[><%>[#@@@@@@@#=      <)@@@@@@@@<[%<<#@@%=           
 *  -]@[=-[@@}>)]}#}])><[%#[#%%]<))[##[])<#@%):+}@<           
 *  =}>:-}@[=*@@]+*--[@@@[:  ]@@@@]--+*#@@++}@]::)}:          
 *  -+ :]#* +@@}<]=*%@@@@%]><#@@@@@#++)<#@@=:<%<  *:          
 *     +[= :@@@%#>+#@@@@@@@@@@@@@@@@[=)#%@@#: *]=             
 *     >+  *@@@@}+]@@@@@@@@@@@@@@@@@@<>%@@@%=  >+             
 *    :-   <@@@@]+}@@@@@@@@@@@@@@@@@@[*#@@@%>  ::             
 *         <@%%@]<@@@@@@@@@@@@@@@@@@@@<}@#%%*                 
 *         >@=>@##@%@@@@@@@@@@@@@@@%%@#%@-=%=                 
 *         =[ :>@@}--<[%@@@@@@@@#]*-*%@%*  [:                 
 *          -   *#}-    -=***+=:    *%}=   =                  
 *               ->-                +>:                       
 *                                                            
 * LFG.CLUB DEPOSIT CONTRACT
 *
 */

// SPDX-License-Identifier: MIT
/**
 * This code is licensed under the MIT License *with the following exception*:
 *
 * Any use of this code — including modified versions — on a non-testnet network must send
 * 15% of all fee revenue, denominated in the native coin of the respective chain (e.g., ETH
 * on Base, ETH on Arbitrum, BNB on BNB Smart Chain), to the original author at:
 *
 * Address: 0xYourAddress
 *
 * This address can be configured in FeeAccount.sol as the `alwaysInShare` address,
 * which will handle the revenue sharing automatically.
 *
 * Deployments of this code on chains where the original author has already deployed
 * the protocol must not set buy/sell fees or Uniswap/Pancakeswap migration fees
 * below those set by the original deployment on that chain.
 *
 * On chains where the original author has not yet deployed the protocol, any deployment
 * must not set fees lower than 0.25% on buy/sell actions or DEX migration features.
 *
 * The first deployments by the original author are on: Ethereum Mainnet, Base, Arbitrum,
 * Unichain, and BNB Smart Chain.
 *
 * Failure to comply with these requirements voids the license.
 */

import "./pool.sol";
import "./factoryERC20.sol";
import "./standardERC20_nocurve.sol";

contract depositor {

    uint256 public totalDeposited;
    address public feeOwner;
    address creator;
    address public factory;

    address public token;

    uint256 public splitAmount;

    uint256 totalSupply = 1e27;
    uint256 maxDeposit = totalSupply * 125 / 100000;
    uint256 multiplierNoEth = 1;

    bool tokenSet;

    mapping(address account => uint256) private _lastAction;
    mapping(address account => uint256) private _rewardAtDeposit;
    mapping(address account => uint256) public _depositedTokens;
    mapping(address account => uint256) public _missedPayout;

    uint256 public totalDepositors;
    uint256 totalRewardPerToken;

    uint256 poolContract;

    address WETH;

    modifier onlyFeeOwner() {
        require(feeOwner == msg.sender, "Caller is not the feeOwner");
        _;
    }

    modifier onlyFactoryCreator() {
        require(creator == msg.sender, "Caller is not the factoryCreator");
        _;
    }

    constructor(address factory_){
        creator = msg.sender;
        WETH = Factory(factory_).WETH9();
        feeOwner = Factory(factory_).feeOwner();
        factory = factory_;

        _setNative();
    }

    function _setNative() internal {
        address native = Factory(factory)._nativeAddress();
        if (native != address(0)) {
            tokenSet = true;
            token = native;
        }
    }

    function modifySplit(uint256 number) public onlyFeeOwner {
        require((number >= 3300) && (number <= 8500), "SPLIT_BETWEEN_3300_8500");
        require(tokenSet, "DEPOSIT_NOT_ACTIVE");
        splitAmount = number;
    }

    function getSplit() public view returns (uint256 number) {
        if (!tokenSet) {
            number = 0;
        } else {
            number = splitAmount;
        }
    }

    // @dev    This function only exists to really double check that we set the right contract address.
    function setToken(address ca, address poolToken0) public onlyFeeOwner {
        require(tokenSet == false, "TOKEN_SET");
        require(poolToken0 == ca, "POOL_TOKEN_DIFFERENT");
        token = ca;
        tokenSet = true;
    }

    receive() external payable {
        // @dev   Max deposit is 1e27 (= total supply), to retain accuracy we need to multiplay with a multiplier. Lets say 1e30.
        totalRewardPerToken += (totalDeposited > 0) ? ((msg.value * 1e30) / totalDeposited) : 0;
    }
    fallback() external payable {
        totalRewardPerToken += (totalDeposited > 0) ? ((msg.value * 1e30) / totalDeposited) : 0;
    }

    // @dev    Deposit function
    function deposit(uint256 amount) public {
        require(tokenSet, "DEPOSIT_NOT_ACTIVE");
        require(amount > 0, "NO_0_DEPOSIT");
        require(amount <= IWETH9(token).balanceOf(msg.sender), "NOT_ENOUGH_TOKENS");
        require((_lastAction[msg.sender] + 10 minutes) <= block.timestamp, "WAIT_10_MIN");
        require((_depositedTokens[msg.sender] + amount) <= maxDeposit,"MAX_DEPOSIT_1250000");

        if (_calculateReward(msg.sender)) {
            _claim(msg.sender);
        }

        IWETH9(token).transferFrom(msg.sender, address(this), amount);

        totalDepositors += (_depositedTokens[msg.sender] == 0) ? 1 : 0; // here fail fix it
        _depositedTokens[msg.sender] += amount;
        totalDeposited += amount;

        _rewardAtDeposit[msg.sender] = totalRewardPerToken;

        _lastAction[msg.sender] = block.timestamp;
    }

    // @dev    Shows how much payout the user would receive if he withdraws or claims right now.
    function pendingReward() public view returns (uint256 reward) {
        reward = (((totalRewardPerToken - _rewardAtDeposit[msg.sender]) * _depositedTokens[msg.sender]) / 1e30) + _missedPayout[msg.sender];
    }

    function _calculateReward(address account) internal returns (bool reward) {
        if (_depositedTokens[account] > 0) {
            // reward is: (rewardPerTokenCurrent - rewardPerTokenAtStakeBegin) * tokensStaked
            // divide by the introduced multiplier here
            uint256 out = ((totalRewardPerToken - _rewardAtDeposit[account]) * _depositedTokens[account]) / 1e30;
            _missedPayout[account] += out;

            _rewardAtDeposit[account] = totalRewardPerToken;

            reward = (_missedPayout[account] >= 5e15) ? true : false;

        } else {
            reward = false;
        }   
    }

    // @dev    Claim function
    function claim() public {
        require(tokenSet, "DEPOSIT_NOT_ACTIVE");
        require(_calculateReward(msg.sender), "ACCUMULATE_0.005ETH");
        require((_lastAction[msg.sender] + 10 minutes) <= block.timestamp, "WAIT_10_MIN");
        _lastAction[msg.sender] = block.timestamp;

        _claim(msg.sender);
    }

    function _claim(address account) internal {
        // @dev    We are already checking if there is a payout earlier, so here just transfer out.

        uint256 payout = _missedPayout[account];
        _missedPayout[account] = 0;        
        payable(account).transfer(payout);
    }

    // @dev    Withdraw function
    function withdraw(uint256 amount) public {
        require(tokenSet, "DEPOSIT_NOT_ACTIVE");
        require(amount > 0, "NO_0_WITHDRAW");
        require(amount <= _depositedTokens[msg.sender], "TOO_MUCH_REQUESTED");
        require((_lastAction[msg.sender] + 10 minutes) <= block.timestamp, "WAIT_10_MIN");

        if (_calculateReward(msg.sender)) {
            _claim(msg.sender);
        }

        _depositedTokens[msg.sender] -= amount;
        totalDeposited -= amount;

        totalDepositors -= (amount == _depositedTokens[msg.sender]) ? 1 : 0;

        IWETH9(token).transfer(msg.sender, amount);

        _lastAction[msg.sender] = block.timestamp;
    }

    // @dev    In case of any unforseen stuff...
    function _addETH() public payable onlyFeeOwner returns (bool) {
        return true;
    }

    // @dev   Splits the amount between feeOwner and depositors.
    function _split(uint256 amount) internal {
        uint256 split = 0;
        uint256 amnt = 0;
        // check if somebody has deposited
        uint256 totS = totalDepositors;
        uint256 splT = getSplit();
        if ((totS > 0) && (splT > 0)) {
            split = splT;
        }

        if (split > 0) {
        amnt = (amount)/10000 * split;
        }
        payable(feeOwner).transfer(amount - amnt);

        // @dev   receive() nor fallback() are triggered when using this function. So we need to add to rewards within the split.
        totalRewardPerToken += (totalDeposited > 0) ? ((amnt * 1e30) / totalDeposited) : 0;
    }

    // @dev    for toolbox: launch token without bonding curve
    function launchToken(string memory name, string memory symbol, uint256 _totalSupply, uint8 decimals) public payable returns (address _tokenAddress) {
        address _poolAddress = Factory(factory)._poolAddress();
        uint256 eTP = ThePool(payable(_poolAddress)).ethToPool();
        uint256 required = 0.025 * 10 ** 18;
        // @dev this lowers/highers the amount if certain USD/ETH is reached.
        if (eTP >= 6.9 * 10 ** 18) {
            require(msg.value >= (0.015 * (10 ** 18) * multiplierNoEth), "FEE_TOO_LOW");
        } else if (eTP >= 4.2 * 10 ** 18) {
            require(msg.value >= (0.01 * (10 ** 18) * multiplierNoEth), "FEE_TOO_LOW");
        } else if (eTP >= 2.1 * 10 ** 18) {
            require(msg.value >= (0.005 * (10 ** 18) * multiplierNoEth), "FEE_TOO_LOW");
        } else {
            require(msg.value >= (0.015 * (10 ** 18) * multiplierNoEth), "FEE_TOO_LOW");
        }

        _tokenAddress = address(new LFGClubTokenNoCurve(name, symbol, _totalSupply, decimals));
        iERC20(_tokenAddress).transfer(msg.sender, _totalSupply * decimals);

        _split(msg.value);
    }
}