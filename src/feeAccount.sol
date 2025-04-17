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
 * LFG.CLUB FEEOWNER CONTRACT
 *
 */

// SPDX-License-Identifier: LicenseRef-LFG-Commercial
// Full license: https://github.com/lfgclub/lfgclub/blob/main/LICENSE
pragma solidity ^0.8.20;

import "./standardERC20.sol";
import "./factoryERC20.sol";
import "./pool.sol";
import "./FullMath.sol";
import "./sqrtX96Math.sol";
import "./depositContract.sol";

contract FeeCollector {

    address public feeOwner;
    address public factoryAddress;
    address public specialAddress;

    uint256 public lastChangeAuthorization;

    mapping(address => bool) public authorized;

    address[] public authorizedArray;
    uint256[] public shareArray;

    mapping(address => uint256) public lockedTokensTotal;
    mapping(address => uint256) public lockedNativeTokensTotal;

    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
    }

    struct LockNativeInfo {
        uint256 amount;
        uint256 unlockTime;       
        address tokenOwner; 
    }

    uint256 public uniV3ID;
    address uniV3pool;

    address public WETH;
    address nativeToken;

    uint256 lastETHChange;

    // @dev    As this contract is open source but with a modified license, 
    // @dev    usage and modification of this contract is only allowed if
    // @dev    at least 15% of all fees are forwarded to the contract creator.
    // @dev    Here the address is set.
    address alwaysInShare = 0x5C18eec0B15B962DAd08a4d2CBAF7C66eE98b93c;

    uint256 setFeeLast;
    uint256 setSplitLast;

    mapping(address => LockInfo[]) public locks;
    mapping(address => LockNativeInfo[]) public nativeLocks;

    event TokensLocked(address indexed token, uint256 amount, uint256 unlockTime);
    event TokensUnlocked(address indexed token, uint256 amount);
    event LockChange(address indexed token, uint256 amount, uint256 unlockTime, address newOwner); 

    Iv3Factory v3Factory;
    INonfungiblePositionManager v3positionManager;

    address v3posm;

    bool v3added;

    constructor(address _factory, address _feeOwner, address _WETH, address v3factory_, address v3manager_) {
        feeOwner = _feeOwner;
        specialAddress = feeOwner;
        factoryAddress = _factory;

        setSharesOnInit();

        WETH = _WETH;

        v3posm = v3manager_;
        v3Factory = Iv3Factory(v3factory_);
        v3positionManager = INonfungiblePositionManager(v3manager_);
    }

    receive() external payable {}
    fallback() external payable {}

    modifier onlyFeeOwner() {
        require(feeOwner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    modifier isInAuthorizedShare() {
        require(authorized[msg.sender] == true, "Caller is not authorized.");     
        _;   
    }

    modifier isSpecialAddress() {
        require(specialAddress == msg.sender, "Caller is not authorized.");     
        _;   
    }

    function setSharesOnInit() internal {
        if (alwaysInShare == feeOwner) {
            authorized[feeOwner] = true;

            authorizedArray.push(feeOwner);
            shareArray.push(10000);
        } else {    
            // @dev    alwaysInShare needs to be position 1.
            authorized[alwaysInShare] = true;  
            authorizedArray.push(alwaysInShare);
            shareArray.push(1500);              

            authorized[feeOwner] = true;
            authorizedArray.push(feeOwner);
            shareArray.push(8500);            
        }
    }

    // @dev    This locks the token this contract receives during migration.
    // @dev    50% for 2.5 min on testnet, and 183 days on mainnet
    // @dev    50% for 10 min on testnet, and 366 days on mainnet
    function lockTokens(address token, uint256 tokenID) external {
        require(msg.sender == payable(Factory(factoryAddress)._poolAddress()),"Caller is not pool contract.");
        uint256 tokenBalance = ERC20(token).balanceOf(address(this));
        uint256 half = tokenBalance/2;

        uint256 unlockTime1 = 2.5 minutes; //---!! testnet: 2.5 min // mainnet: 183 days
        uint256 unlockTime2 = 10 minutes; //---!! testnet: 10 min // mainnet: 366 days

        locks[token].push(LockInfo(half, block.timestamp + unlockTime1));
        locks[token].push(LockInfo(tokenBalance - half, block.timestamp + unlockTime2));
        lockedTokensTotal[token] = tokenBalance;

        emit TokensLocked(token, half, block.timestamp + unlockTime1);
        emit TokensLocked(token, tokenBalance - half, block.timestamp + unlockTime2);
    }

    // @dev    Unlocks tokens this contract received during migration to make them available for withdraw.
    function unlockTokens(address token) external isInAuthorizedShare {
        uint256 totalWithdrawable = 0;
        LockInfo[] storage tokenLocks = locks[token];

        for (uint256 i = 0; i < tokenLocks.length; i++) {
            if (tokenLocks[i].unlockTime <= block.timestamp && tokenLocks[i].amount > 0) {
                totalWithdrawable += tokenLocks[i].amount;
                tokenLocks[i].amount = 0; // Mark as unlocked
            }
        }

        require(totalWithdrawable > 0, "No tokens available for unlock.");
        lockedTokensTotal[token] -= totalWithdrawable;
        emit TokensUnlocked(token, totalWithdrawable);
    }

    /*
    -----    -----    -----    -----    -----    -----    -----    -----
    -----    -----    -----    -----    -----    -----    -----    -----
    -----    -----    -----    -----    -----    -----    -----    -----

    LOCK FUNCTIONS FOR THE NATIVE TOKEN

    -----    -----    -----    -----    -----    -----    -----    -----
    -----    -----    -----    -----    -----    -----    -----    -----
    -----    -----    -----    -----    -----    -----    -----    -----
    */

    // lock native token; this is apart from the lock function to not confuse the different locks.
    // Basically this could lock every erc20 token.
    function lockTokensNative(address token, uint256 amount, uint256 unlockTime, bool holder) public onlyFeeOwner {
        require(nativeToken != address(0), "NATIVE_NOT_SET");

        if (holder) {
            // contract holds tokens already. Check it if it is true.
            uint256 tokenBalance = ERC20(token).balanceOf(address(this));
            require(amount <= tokenBalance,"Error: Amount cannot be higher than balance of tokens in this contract.");
        } else {
            // msg.sender holds tokens. Check if it is true.
            uint256 tokenBalance = ERC20(token).balanceOf(msg.sender);
            require(amount <= tokenBalance,"Error: Amount cannot be higher than your token balance.");

            // needs to be approved obviously
            IWETH9(token).transferFrom(msg.sender, address(this), amount);
        }

        nativeLocks[token].push(LockNativeInfo(amount, block.timestamp + unlockTime, msg.sender));
        lockedNativeTokensTotal[token] += amount;

        emit TokensLocked(token, amount, block.timestamp + unlockTime);
    }

    // transfer ownership of lock
    function transferNativeLock(address token, address target, uint256 lockId) external {
        require(nativeToken != address(0), "NATIVE_NOT_SET");
        require(nativeLocks[token][lockId].amount > 0, "Error: Tokens of this lockID are already withdrawn or lockID does not exist.");
        require(nativeLocks[token][lockId].tokenOwner == msg.sender, "Error: Owner of this token lockID is not the caller.");

        nativeLocks[token][lockId].tokenOwner = target;

        emit LockChange(token, nativeLocks[token][lockId].amount, nativeLocks[token][lockId].unlockTime, nativeLocks[token][lockId].tokenOwner);
    }

    // extend lock
    function extendNativeLock(address token, uint256 newUnlockTime, uint256 lockId) external {
        require(nativeToken != address(0), "NATIVE_NOT_SET");
        require(nativeLocks[token][lockId].amount > 0, "Error: Tokens of this lockID are already withdrawn or lockID does not exist.");
        require(nativeLocks[token][lockId].tokenOwner == msg.sender, "Error: Owner of this token lockID is not the caller.");
        require(nativeLocks[token][lockId].unlockTime < (block.timestamp + newUnlockTime), "Error: New unlock time of token lockID needs to be higher than current unlock time.");

        nativeLocks[token][lockId].unlockTime = block.timestamp + newUnlockTime;

        emit LockChange(token, nativeLocks[token][lockId].amount, nativeLocks[token][lockId].unlockTime, nativeLocks[token][lockId].tokenOwner);
    }

    // unlock native tokens
    function unlockTokensNative(address token) external {
        require(nativeToken != address(0), "NATIVE_NOT_SET");
        uint256 totalWithdrawable = 0;
        LockNativeInfo[] storage tokenLocks = nativeLocks[token];

        for (uint256 i = 0; i < tokenLocks.length; i++) {
            if ((tokenLocks[i].unlockTime <= block.timestamp) && (tokenLocks[i].amount > 0) && (tokenLocks[i].tokenOwner == msg.sender)) {
                totalWithdrawable += tokenLocks[i].amount;
                tokenLocks[i].amount = 0; // Mark as unlocked
            }
        }

        require(totalWithdrawable > 0, "Error: No tokens available for unlock.");
        lockedTokensTotal[token] -= totalWithdrawable;
        emit TokensUnlocked(token, totalWithdrawable);
    }        

    // @dev     Withdraw native token.
    // @dev     To preserve the intended vesting percentage relative to the circulating supply,
    // @dev     a proportional burn is applied on withdrawal. Specifically, a fraction of the withdrawn
    // @dev     tokens—equivalent to the current burned ratio (i.e. the percentage of total supply
    // @dev     held by the burn address)—will be burned. This ensures that, for example, if 15% of
    // @dev     the total supply is burned at the time of withdrawal, then 15% of the tokens withdrawn
    // @dev     are burned as well. In turn, the relative proportion of tokens locked (e.g., 25%) remains
    // @dev     constant with respect to the circulating supply.
    function withdrawNativeTokens() public onlyFeeOwner {
        require(nativeToken != address(0), "NATIVE_NOT_SET");
        address token = nativeToken;
        
        uint256 tokenBalance = ERC20(token).balanceOf(address(this));
        require(tokenBalance > 0,"No Token balance.");

        // check if some of the tokens are locked

        if (lockedNativeTokensTotal[token] > 0) {
            uint256 lockedBalance = lockedNativeTokensTotal[token];

            tokenBalance -= lockedBalance;
            require(tokenBalance > 0, "No unlocked tokens.");
        }

        // calculate how much % is burned

        uint256 burnBalance = ERC20(nativeToken).balanceOf(0x000000000000000000000000000000000000dEaD);
        uint256 burnRatio = burnBalance * 1e35 / 1e27; // 1e27 = total supply with decimals, we need to multiply burnBalance with a multiplier.
        for (uint256 i = 0; i < authorizedArray.length; i++) {
            uint256 shareAmount = FullMath.mulDiv(tokenBalance, shareArray[i], 10000);
            // Calculate the burn portion based on burnRatio
            uint256 burnAmount = FullMath.mulDiv(shareAmount, burnRatio, 1e35);
            // Authorized recipients receive the remainder
            uint256 authorizedAmount = shareAmount - burnAmount;
            ERC20(token).transfer(authorizedArray[i], authorizedAmount);
            ERC20(token).transfer(0x000000000000000000000000000000000000dEaD, burnAmount);
        } 
    }

    // @dev    Withdraws the collected ETH, split up between the share holders.
    function withdrawETH() public isInAuthorizedShare {
        uint256 balanceContract = address(this).balance;
        require(balanceContract > 0,"No ETH balance.");

        for (uint256 i = 0; i < authorizedArray.length; i++) {
            uint256 amount = FullMath.mulDiv(balanceContract,shareArray[i],10000);
            payable(authorizedArray[i]).transfer(amount);
        }        

    }

    // @dev    Withdraws the collected token <tokenContract>, split up between the share holders.
    function withdrawTokens(address token) public isInAuthorizedShare {
        require(token != nativeToken,"Wrong function for native.");
        uint256 tokenBalance = ERC20(token).balanceOf(address(this));
        require(tokenBalance > 0,"No Token balance.");

        // check if some of the tokens are locked

        if (lockedTokensTotal[token] > 0) {
            uint256 lockedBalance = lockedTokensTotal[token];

            tokenBalance -= lockedBalance;
            require(tokenBalance > 0, "No unlocked tokens.");
        }

        for (uint256 i = 0; i < authorizedArray.length; i++) {
            uint256 amount = FullMath.mulDiv(tokenBalance,shareArray[i],10000);
            ERC20(token).transfer(authorizedArray[i], amount);
        }  
    }

    // @dev    Modifies the share holders.
    // @dev    Syntax: [address1, addres2, address3, ...], [share1, share2, share3, ...]
    // @dev    Sum of share array must be exactly 10000.
    function changeAuthorization(address[] memory accounts, uint256[] memory shares) public onlyFeeOwner {
        // add that it can only be changed once weekly
        require((lastChangeAuthorization + 10 minutes) < block.timestamp, "Change only allowed every 10 minutes."); //---!! testnet: 10 min // main: 1 week
        // testnet: 10 min // mainnet: 2 weeks
        //
        require((accounts[0] == alwaysInShare) && (shares[0] >= 1500),"Contract creator needs to be in index 0 and over or equal 1500. Read license.");
        uint256 totalSum;

        // first check that sum of shares is not >10000 and clear the maps
        for (uint i = 0; i < shares.length; i++) {
            totalSum += shares[i];
        }

        require(totalSum == 10000, "Error: Sum of shares need to be exactly 10000.");

        // first empty the mappings
        for (uint256 i = 0; i < authorizedArray.length; i++) {
            authorized[authorizedArray[i]] = false;
        }
        // now clear the arrays
        delete authorizedArray;
        delete shareArray;

        // set the new array and maps

        for (uint256 i = 0; i < accounts.length; i++) {
            authorized[accounts[i]] = true;
            authorizedArray.push(accounts[i]);
            shareArray.push(shares[i]);
        }

        lastChangeAuthorization = block.timestamp;        
    }

    // @dev    Lets us update the metadata of tokens on the website.
    // @dev    Use only if shenanigans have happened.
    function updateMetadata(uint256 id, string[5] memory metad) public isInAuthorizedShare {
        Factory(factoryAddress)._updateMetadata(id, metad);
    }

    // @dev    Burns the address for deactivation of new token creations. 
    // @dev    This action is irrevocable.
    // -----------
    // @dev    On burning this address the creation of new tokens 
    // @dev    can no longer be activated/deactivated.
    // @dev    When calling this function <name> will become fully
    // @dev    decentralized and can no longer be censored. 
    // @dev    The deactivation function of new token creation is only 
    // @dev    implimented in case there is a critical bug. All deployed
    // @dev    tokens will continue be tradeable and migration can also
    // @dev    happen normally.
    // @dev    Why fully decentralized? Because <name> is NOT upgradable.
    // @dev    I.e. a new contract with bug fixes needs to be deployed.
    // @dev    This is intentional.
    function burnSpecialAddress() public isSpecialAddress {
        specialAddress = address(0);
    }

    // @dev    Deactivates creation of new tokens. Only call this if
    // @dev    a critical bug was detected.
    function factoryFlag(bool flag) public isSpecialAddress {
        Factory(factoryAddress).update(flag);
    }

    // @dev    Sets the fee level of buy/sell on the pool contract.
    // @dev    As only feeContract can change the fee we enforce the
    // @dev    1 day wait between fee changes here.
    function setFee(uint256 bps) public onlyFeeOwner {
        require((setFeeLast + 2 minutes) <= block.timestamp, "WAIT_1_DAY"); //---!! testnet: 2 min // main: 1 day
        address pool = Factory(factoryAddress)._poolAddress();
        ThePool(payable(pool)).setCurveFee(bps);
        setFeeLast = block.timestamp;
    }

    // @dev    Sets that all new migrations to launch as Uniswap V4 pool.
    function launchPoolAsV4(bool flag) public onlyFeeOwner {
        Factory(factoryAddress).launchPoolAsV4(flag);        
    }

    // @dev    Changes the order of which the v4 pools will be checked and launched.
    function changeV4order(uint8[7] memory array) public onlyFeeOwner {
        address pool = Factory(factoryAddress)._poolAddress();
        ThePool(payable(pool)).v4order(array);
    }

    // @dev    Modifies the splitting between depositers and feeContract.
    // @dev    Can only be between 33% (lowest) and 85% (highest), denominated
    // @dev    as 3300 and 8500.
    function modifySplitting(uint256 number) public onlyFeeOwner {
        require((setSplitLast + 2 minutes) <= block.timestamp, "WAIT_14_DAYS"); //---!! testnet 2 min // main: 14 days
        address depositAddress = Factory(factoryAddress)._depositAddress();
        depositor(payable(depositAddress)).modifySplit(number);
        setSplitLast = block.timestamp;
    }
    // @dev    In case of any unforseen stuff.
    function _addDeposit() public payable onlyFeeOwner {
        address depositAddress = Factory(factoryAddress)._depositAddress();
        depositor(payable(depositAddress))._addETH{value: msg.value}();
    }

    // @dev    Sets the native token for the Deposit Contract.
    // @dev    This is needed for expansions to other networks, if deposits should be
    // @dev    activated.
    function setNativeOnDepositContract(address ca) public onlyFeeOwner {
        address depositAddress = Factory(factoryAddress)._depositAddress();
        depositor(payable(depositAddress)).setToken(ca, nativeToken);
    }

    // @dev    Updates the ETH needed for pool completion for new bonding curve launches.
    function updateETH(uint256 priceETH) public onlyFeeOwner {
        require((lastETHChange + 2 minutes) <= block.timestamp, "WAIT_14_DAYS"); //---!! testnet 2 min // main: 14 days
        address pool = Factory(factoryAddress)._poolAddress();
        ThePool(payable(pool))._updateRequirements(priceETH);
        lastETHChange = block.timestamp;
    }

    // @dev    Collects fees of the Uniswap pools.
    // @dev    If native tokens have been deposited the splitting is
    // @dev    between the feeCollector and depositers. This split can
    // @dev    be set between 33% and 66% of ETH. Only ETH is splitted,
    // @dev    while tokens get burned with the same split model. I.e.
    // @dev    if 33% of ETH goes to depositers, also 33% of tokens get
    // @dev    burned forever. If 50%, then 50% gets burned, etc.
    // --------
    // @dev    Team decides what to do with the rest of the tokens,
    // @dev    e.g. adding permanently to liquidity, burning, covering
    // @dev    expenses etc.
    function collect(uint256 tokenID) public isInAuthorizedShare {
        address pool = Factory(factoryAddress)._poolAddress();

        // @dev    token1 in bondingCurve is always WETH, so we only need token0.

       // address theToken0 = address(0); //abi.decode(ThePool(payable(pool)).bondingCurve(tokenID, 0x01), (address));
        ( , , , , address theToken0, , , , , , , , , , , ) = ThePool(payable(pool)).getBondingCurve(tokenID);
        //address theToken0 = bC.token0;

        uint256 beforeETH = address(this).balance;
        uint256 beforeToken = ERC20(theToken0).balanceOf(address(this));

        address depositAddress = Factory(factoryAddress)._depositAddress();
        ThePool(payable(pool)).claim(tokenID);

        uint256 afterETH = address(this).balance;
        uint256 afterToken = ERC20(theToken0).balanceOf(address(this));        

        // @dev    First get split amount from the staking contract,
        // @dev    if it is 0 or if there are 0 stakers, don't do any split.
        // @dev    As eth & tokens are already in this contract we only need to perform
        // @dev    the split if requirements are met.

        if (depositAddress != address(0)) {
            uint256 splitAmt = depositor(payable(depositAddress)).getSplit();
            if ((depositor(payable(depositAddress)).totalDepositors() > 0) && (splitAmt > 0)) {
                uint256 receivedETH = afterETH - beforeETH;
                uint256 receivedTokens = afterToken - beforeToken;

                uint256 splittedETH = FullMath.mulDiv(receivedETH, splitAmt, 10000);
                uint256 splittedToken = FullMath.mulDiv(receivedTokens, splitAmt, 10000);
                (bool success, ) = payable(depositAddress).call{value: splittedETH}("");
                require(success, "TX_FAIL");
                ERC20(theToken0).transfer(0x000000000000000000000000000000000000dEaD, splittedToken);
            }
        }
    }

    // @dev    Withdraws everything from the bondingCurve of the associated tokenID. Can only be
    // @dev    called if an automatic manipulation during migration to Uniswap has been detected.
    // @dev    I.e. it cannot be set manually.
    function emergencyWithdraw(uint256 tokenID) public onlyFeeOwner {
        address pool = Factory(factoryAddress)._poolAddress();
        ThePool(payable(pool)).emergencyWithdrawal(tokenID, msg.sender);

        // @dev    ETH + tokens get send immidiately to feeOwner to not mix them up with other functions here
        // @dev    as refunds need to managed either way by the feeOwner and not by the contract.
    }

    
    // @dev    ADD LIQUIDITY FUNCTION FOR THE NATIVE TOKEN FOR UNISWAP V3.
    // @dev    This locks liquidity as NFT is transferred directly to the contract.
    // @dev    Only function available is claim.
    function addLiquidityNative(address token, uint256 amountToken) public payable onlyFeeOwner {
        require(v3added == false, "Error: Native token pool has already been created.");
        nativeToken = token;
        address token00 = nativeToken;
        address token11 = WETH;

        uint256 reserve0 = amountToken;
        uint256 reserve1 = msg.value;

        IWETH9(WETH).deposit{value: reserve1}();

        IWETH9(WETH).approve(v3posm, type(uint256).max);

        // @dev    Native token must be transfered to this contract first -> as we use transferFrom the caller needs to approve the tokens first
        // @dev    to this contract!
        IWETH9(token00).transferFrom(msg.sender, address(this), amountToken);
        IWETH9(token00).approve(v3posm, type(uint256).max);

        uniV3pool = v3Factory.createPool(token00, token11, 10000);
        address token0addr = Iv3Pool(uniV3pool).token0();

        uint160 sqrtX = (token0addr != token11) ? SqrtX96Math.getSqrtPriceX96(reserve0, reserve1, 18, 18) : SqrtX96Math.getSqrtPriceX96(reserve1, reserve0, 18, 18);
        Iv3Pool(uniV3pool).initialize(sqrtX);

        (uint256 tokenId, uint128 liquidity, uint256 amount0Used, uint256 amount1Used) = v3positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: (token0addr != token11) ? token00 : token11,
                token1: (token0addr != token11) ? token11 : token00,
                fee: 10000,
                tickLower: -887200,
                tickUpper: 887200,
                amount0Desired: (token0addr != token11) ? reserve0 : reserve1,
                amount1Desired: (token0addr != token11) ? reserve1 : reserve0,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        uniV3ID = tokenId;
        v3added = true;
    }

    // @dev    CLAIM FEE FOR THE NATIVE TOKEN FOR UNISWAP V3.
    // @dev    Fees from trading the native token is split up following:
    // @dev    -- Native Coin: ETH, BNB, etc., on claim():
    // @dev    100% of native coin goes to feeOwner Contract (no split up).
    // @dev    -- Native token for project, on claim():
    // @dev    75% of native token will be burned.
    // @dev    12.5% is transfered to feeOwner Contract and locked up for 6 months.
    // @dev    12.5% is transfered to feeOwner Contract and immediately available.
    function claimNativeFee() public onlyFeeOwner {
            require(v3added, "Error: Native token pool has not been created.");
            INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
                    tokenId: uniV3ID,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
            });

            // @dev    As we are receiving here the native token, which could be deposited,
            // @dev    we need to take a snapshort before and after claim.
            // @dev    The native token, and weth before and after. Convert the weth to ETH.

            uint256 beforeETH = IWETH9(WETH).balanceOf(address(this));
            uint256 beforeNative = IWETH9(nativeToken).balanceOf(address(this));

            v3positionManager.collect(params);

            uint256 aftrETH = IWETH9(WETH).balanceOf(address(this));
            uint256 aftrNative = IWETH9(nativeToken).balanceOf(address(this));

            uint256 WETHAmount = aftrETH - beforeETH;
            uint256 NativeAmount = aftrNative - beforeNative;

            IWETH9(WETH).withdraw(WETHAmount);

            uint256 lockAmount = FullMath.mulDiv(NativeAmount, 12500, 100000);

            // @dev    Burn
            IWETH9(nativeToken).transfer(0x000000000000000000000000000000000000dEaD, lockAmount * 6);
            // @dev    Lock
            lockTokensNative(nativeToken, lockAmount, 184 days, true); // lock
    }

}
