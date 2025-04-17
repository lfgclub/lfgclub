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
 * LFG.CLUB POOL CONTRACT (BONDING CURVE)
 *
 */

// SPDX-License-Identifier: LicenseRef-LFG-Commercial
// Full licence: https://github.com/lfgclub/lfgclub/blob/main/LICENSE
pragma solidity ^0.8.20;

import "./standardERC20.sol";
import "./FullMath.sol";
import "./feeAccount.sol";
import "./depositContract.sol";
import "./sqrtX96Math.sol";

////////// ERC20 & WETH interface
interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

////////// Uniswap V4 interfaces
interface IUniswapV4PoolManager {
    struct PoolKey {
        address currency0; address currency1; uint24 fee;
        int24 tickSpacing; address hooks;
    }
}

interface V4PositionManager {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
    function initializePool(IUniswapV4PoolManager.PoolKey calldata key, uint160 sqrtPriceX96) external payable returns (int24);
    function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external payable;
    function nextTokenId() external view returns (uint256);
    function getPoolAndPositionInfo(uint256 tokenId) external view returns (IUniswapV4PoolManager.PoolKey memory poolKey, uint256 info);
    function poolKeys(bytes25 poolId) external view returns (IUniswapV4PoolManager.PoolKey memory poolKey);
}

interface IAllowanceTransfer {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

////////// Uniswap V3 interfaces
interface Iv3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
}

interface Iv3Pool {
    function initialize(uint160 sqrtPriceX96) external;
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked);
    function token0() external returns (address token0);
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0; address token1; uint24 fee; int24 tickLower; int24 tickUpper; uint256 amount0Desired;
        uint256 amount1Desired; uint256 amount0Min; uint256 amount1Min; address recipient; uint256 deadline;
    }

    struct CollectParams { uint256 tokenId; address recipient; uint128 amount0Max; uint128 amount1Max; }

    function mint(MintParams calldata params) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);
}

////////// Uniswap V2 interfaces
interface Iv2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface Iv2Router {
    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity);
}

////////// Start of contract
contract ThePool {
    uint256 startVETH;
    uint256 initVirtualTokens;

    uint64 tokenMultiplier0 = 12261203585147251;
    uint48 tokenMultiplier1 = 100000000000000;

    uint256 minimumTokens;
    uint256 minimumTokensTransfer;

    address token0addr;
    uint80 public ethToPool;

    address feeOwner;
    uint256 public feeOnCurve = 100; /*in bps: 100=1%, 1=0.01% etc.*/

    address factory;
    address WETH;

    // @dev    Uniswap V3 Factory Address
    address public _v3Factory = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;
    // @dev    Uniswap V3 NFT Manager Address
    address public _v3positionManager = 0x1238536071E1c677A632429e3655c799b22cDA52;
    // @dev    Uniswap V3/V4 Permit2 Address
    address uniPermit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // @dev    Uniswap V2 Router Address
    address _v2router = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;
    // @dev    Uniswap V2 Factory Address
    address _v2Factory = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;

    // @dev    Uniswap V4 Pool Manager Address
    address public immutable uniswapV4Manager = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    // @dev    Uniswap V4 Position Manager Address
    address v4POSM = 0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4;
    // @dev    Launching as V4?
    bool launchAsV4;
    uint24 v4launcher;

    Iv3Factory v3Factory;
    INonfungiblePositionManager v3positionManager;

    Iv2Factory v2Factory;
    Iv2Router v2router;

    address depositAccount;

    mapping(uint24 _fee => int24 tickSpacing) public getTicks;  
    mapping(uint24 _fee => int24 maxTicks) public getMaxTicks;

    // @dev    The Bonding Curve struct is actually declared this way
    // @dev    as this is the most gas efficient storage, to minimize
    // @dev    storage slots used.

    // @dev    token0 is always the token, and token1 always ETH.
    struct BondingCurve {
        address creator;       // 20B
        bool launchAsV4;       // 1B
        bool migrated;         // 1B
        uint80 ethPool;        // 10B max: max: ~1.2 million eth (+18 decimals)
        // > 32B (1 slot)

        address token0;        // 20B
        uint96 reserve1;       // 12B max: ~309 million eth (+18 decimals)
        // > 32B (1 slot)

        address token1;        // 20B
        uint96 virtualETH;     // 12B max: ~309 million eth (+18 decimals)
        // > 32B (1 slot)

        uint96 reserve0;      // 12B max: ~79 billion tokens (+18 decimals)
        uint96 virtualTokens; // 12B max: ~79 billion tokens (+18 decimals)
        uint48 tokenMul1;      // 6B max: ~281 trillion
        bool manipulation;     // 1B
        bool v2pool;           // 1B
        // > 32B (1 slot)

        // We can cast the uniswap ID's down as even in a spam attack
        // which would utilize 100% of the block every 0.01s they would
        // need 21 trillions years to fill it up. (assuming 500k gas per
        // v4 deployment and 36M gas per block limit). As gas cost on
        // v3 mint is astronomically higher than v4, this question
        // doesn't even arise on v3.

        uint72 uniV4Id;        // 9B
        uint64 uniV3Id;        // 8B
        uint8[7] v4order;      // 7B
        uint64 tokenMul0;      // 8B  max: 1.8 * 10^19
        // > 32B (1 slot)
    } // only 5 storage slots used

    mapping(uint256 _tokenId => BondingCurve) public getBondingCurve;
    mapping(uint256 _tokenId => uint48[]) public swapBlocks;

    event Swap(
        uint256 indexed tokenID,
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        address token0,
        address token1
        );

    // here we need to add if it migrated to v4, v3, or v2
    event Migrate(
        uint256 indexed tokenID,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 movedTo,
        uint256 movedFee
    );

    uint8[7] v4orderArray = [50, 45, 40, 35, 30, 25, 100]; // @dev    For the launch. Multiply by 100 to get real val.
    // I think it is better to let v4order 

    // @dev    Modifier for functions that only the FeeOwner Contract can call 
    modifier onlyFeeOwner() {
        require(feeOwner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor(address _feeOwner, address _factory, bool _launchAsV4, address _WETH, address _depositor) {
        initVirtualTokens = 1073000000 * 10 ** 18;
        minimumTokens = 202000000 * 10 ** 18;
        minimumTokensTransfer = 200000000 * 10 ** 18;
        startVETH = 30 * 10 ** 18;
        ethToPool = 6.9 * 10 ** 18;

        feeOwner = _feeOwner;
        factory = _factory;

        launchAsV4 = true;//_launchAsV4;

        v3Factory = Iv3Factory(_v3Factory);
        v3positionManager = INonfungiblePositionManager(_v3positionManager);

        v2Factory = Iv2Factory(_v2Factory);
        v2router = Iv2Router(_v2router);

        WETH = _WETH;

        depositAccount = _depositor;

        // @dev   Set Uniswap V3/V4 tick and fee levels
        getTicks[2500] = 50; getMaxTicks[2500] = 887250;
        getTicks[3000] = 60; getMaxTicks[3000] = 887220;
        getTicks[3500] = 70; getMaxTicks[3500] = 887250;
        getTicks[4000] = 80; getMaxTicks[4000] = 887200;
        getTicks[4500] = 90; getMaxTicks[4500] = 887220;
        getTicks[5000] = 100; getMaxTicks[5000] = 887200;
        getTicks[10000] = 200; getMaxTicks[10000] = 887200;
    }

    receive() external payable {}
    fallback() external payable {}

    // @dev    Creates the BondingCurve for the token.
    function create(uint256 id, address creator_, address token) external {
        require(msg.sender == factory,"Error: Only callable by the factory contract.");

        getBondingCurve[id] = BondingCurve({
            creator: creator_,
            token0: token,
            token1: WETH,
            reserve0: 1000000000 * 10 ** 18,
            reserve1: 0,
            virtualETH: 30 * 10 ** 18,
            virtualTokens: 1073000000 * 10 ** 18,
            launchAsV4: launchAsV4,
            migrated: false,
            manipulation: false,
            uniV4Id: 0,
            uniV3Id: 0,
            v2pool: false,
            v4order: v4orderArray, // we can delete this and make other values the uint margin bigger
            tokenMul0: tokenMultiplier0,
            tokenMul1: tokenMultiplier1,
            ethPool: ethToPool
        });
    }

    /*
    cant force v4 launch... need to implement function
    */

    function _setV4launch(bool flag) external {
        require(msg.sender == factory,"NOT_FACTORY");        
        launchAsV4 = flag;
    }

    // @dev    helper function
    function getSwapBlocks(uint256 id, uint256 start, uint256 end) public view returns (uint256 length, uint48[] memory blocks)
    {
        uint48[] storage all = swapBlocks[id];
        length = all.length;

        if (start == 0 && end == 0) {
            return (length, new uint48[](0));
        }

        require(end <= length && start < end, "Invalid range");
        blocks = new uint48[](end - start);

        for (uint256 i = 0; i < end - start; i++) {
            blocks[i] = all[start + i];
        }
        return (length, blocks);
    }

// todo: add that we can change the virtual values -> we can decrease how much eth is needed in the future that way if eth just simply explodes.
// todo: add that we stop at 7.1 eth, 0.2 to creator (no staking), or 0.1 / 0.1 if staking. 

    // @dev    As price of ETH is not fixed, we have a scheme how migration will work.
    // @dev    For ETH price < 3450 USD: 6.9 are migrated, and 7.1 are needed to complete curve.
    // @dev    For ETH price >= 3450 USD and < 6900 USD: 4.2 are migrated, and 4.32 are needed.
    // @dev    For ETH price >= 6900 USD: 2.1 are migrated, and 2.16 are needed.

    // @dev    For chains that are not using ETH as native coin we need an additional multiplier,
    // @dev    denominated as nativeCoin/ETH price.

    function _updateRequirements(uint256 priceETH) public onlyFeeOwner {
        if (priceETH < 3450) {
            tokenMultiplier0 = 12261203585147251;
            tokenMultiplier1 = 100000000000000;
            ethToPool = 0.69 * 10 ** 18; //testnet
        } else if ((priceETH >= 3450) && (priceETH < 6900)) {
            tokenMultiplier0 = 829090909090909;
            tokenMultiplier1 = 4000000000000;
            ethToPool = 0.42 * 10 ** 18; // testnet
        } else {
            tokenMultiplier0 = 829090909090909; // uint96
            tokenMultiplier1 = 2000000000000; // uint64
            ethToPool = 0.21 * 10 ** 18; // testnet
        }
    }

    // @dev    Factory will call this function to set also the staking address here.
    function _setDepositor() external {
        require(msg.sender == factory,"NOT_FACTORY");
        depositAccount = Factory(factory)._depositAddress();
    }

    // @dev    This splits the fee if somebody is staking on native token.
    // @dev    Check if staker is even deployed.
    function _split(uint256 amount) internal {
        uint256 splitted = 0;
        if (depositAccount != address(0)) {
            uint256 splitAmt = depositor(payable(depositAccount)).getSplit();
            if ((depositor(payable(depositAccount)).totalDepositors() > 0) && (splitAmt > 0)) {
            splitted = FullMath.mulDiv(amount, splitAmt, 10000);
            (bool success, ) = payable(depositAccount).call{value: splitted}(""); // add gas limit
            require(success, "TX_FAIL");
            }
        }
        payable(feeOwner).transfer(amount - splitted);
    }

    // @dev   If somebody is staking reward is split 50/50 between creator and staker.
    // @dev   If not: 100% to creator
    function _migrationSplit(uint256 amount, address target) internal {
        uint256 splitted = 0;
        if (depositAccount != address(0)) {
            if ((depositor(payable(depositAccount)).totalDepositors() > 0)) {
            splitted = FullMath.mulDiv(amount, 5000, 10000);
            (bool success, ) = payable(depositAccount).call{value: splitted}(""); // add gas limit
            require(success, "TX_FAIL");
            }
        }
        payable(target).transfer(amount - splitted);        
    }

    // @dev    Function for buys. in UpdateReserves we get if pool is ready for migration,
    // @dev    if it is ready, then _migrate() is called.
    function buy(uint256 id, uint256 amountOutMin) public payable returns (uint256 amountOut) {
        BondingCurve storage bC = getBondingCurve[id];
        require(!bC.migrated,"POOL_MIGRATED");
        require(msg.value > 0, "0_ETH_ERROR");

        // @dev    When calling createAndBuy if factory is the one who buys it, that's why
        // @dev    we change it to creator in this case, as it can only be the creator who
        // @dev    calls this function. Saves gas this way instead of doing extra txs.
        address sendTo = (msg.sender == factory) ? bC.creator : msg.sender;
        uint256 realAmountToken = updateReserves(id, 0, msg.value, false, sendTo);
        require(realAmountToken >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH9(bC.token0).transfer(sendTo, realAmountToken);

        if (bC.migrated) {
            _migrate(id);
        }
    }

    // @dev    Pool contract can call transferFrom without approval for sells,
    // @dev    this makes the bonding curve experience way faster and more user friendly
    // @dev    for users.
    // @dev    This is safe as the ERC20 Token transferFrom checks if the caller is
    // @dev    the pool contract. If it's not then allowance is needed.
    function sell(uint256 id, uint256 amountIn, uint256 amountOutMin) public returns (uint256 amountOut) {
        BondingCurve storage bC = getBondingCurve[id];
        require(!bC.migrated,"POOL_MIGRATED");
        require(amountIn > 0,"0_TOKEN_ERROR");
        require(amountIn <= IWETH9(bC.token0).balanceOf(msg.sender),"NOT_ENOUGH_TOKENS");

        IWETH9(bC.token0).transferFrom(msg.sender, address(this), amountIn);

        amountOut = FullMath.mulDiv(FullMath.mulDiv(bC.virtualETH,amountIn,(bC.virtualTokens + amountIn)),bC.tokenMul1,bC.tokenMul0);
        require(amountOut >= amountOutMin,"INSUFFICIENT_OUTPUT_AMOUNT");

        updateReserves(id, amountIn, amountOut, true, msg.sender);

        uint256 feeAmount = FullMath.mulDiv(amountOut, feeOnCurve, 10000);
        _split(feeAmount);
        payable(msg.sender).transfer(amountOut-feeAmount);
        emit Swap(id, msg.sender, address(this), amountIn, amountOut-feeAmount, bC.token0, address(0));
    }

    // @dev    Updates the reserves and also calculates the fees for the buy.
    function updateReserves(uint256 id, uint256 amountOut, uint256 amountIn, bool from0to1, address sender) internal returns (uint256 realOut) {
        BondingCurve storage bC = getBondingCurve[id];
        swapBlocks[id].push(uint48(block.number));
        uint256 realIn;
        uint256 wethAmount;
   
        // buy
        if (!from0to1) {
            // step1: get the real input with the subtracted fee
            wethAmount = FullMath.mulDiv(uint256(amountIn), 10000, (10000 + feeOnCurve));

            // step2: calculate the amountOut we'd receive
            uint256 thetokenMultiplier = FullMath.mulDiv(wethAmount, bC.tokenMul0, bC.tokenMul1);
            amountOut = FullMath.mulDiv(bC.virtualTokens, thetokenMultiplier,(bC.virtualETH + thetokenMultiplier));

            // reserve0 - thisamount < minTokens? trigger refund T_v * E / (E_v + E)

            if ((bC.reserve0 - amountOut) <= minimumTokens) {
                // @dev    Here the migration is triggered. We are refunding the
                // @dev    one who triggered the migration with the buy the excess ETH.
                amountOut = bC.reserve0 - minimumTokens;
                realIn = _refund(id, amountOut, amountIn, sender);
                bC.migrated = true;

                uint256 value = amountIn - realIn;
                address payable target = (sender == factory) ? payable(bC.creator) : payable(sender);
                payable(target).transfer(value);

                wethAmount = FullMath.mulDiv(uint256(realIn), 10000, (10000 + feeOnCurve));
                _split(realIn - wethAmount);
            // else pay the feeowner contract    
            } else {
                _split(amountIn - wethAmount);
            }

            bC.reserve0 -= uint96(amountOut);
            bC.virtualTokens -= uint96(amountOut);    

            bC.reserve1 += uint96(wethAmount);
            bC.virtualETH += uint96(FullMath.mulDiv(wethAmount,bC.tokenMul0,bC.tokenMul1));

            emit Swap(id, sender, address(this), wethAmount, amountOut, address(0), bC.token0);

            realOut = amountOut;  
        // sell
        } else {
            bC.reserve0 += uint96(amountOut);
            bC.virtualTokens += uint96(amountOut);    

            uint96 tempReserve1 = bC.reserve1;
            tempReserve1 -= uint96(amountIn);
            if (tempReserve1 < 1e4) { // @dev    Dust cleanup
                tempReserve1 = 0;
            }
            bC.reserve1 = tempReserve1;  

            uint96 tempVETH = bC.virtualETH;
            tempVETH -= uint96(FullMath.mulDiv(amountIn, bC.tokenMul0, bC.tokenMul1));
            if (tempVETH < uint96(startVETH + 1e4)) { // @dev   Dust cleanup
                tempVETH = uint96(startVETH);
            }
            bC.virtualETH = tempVETH;
        } 
    }

    // @dev    If the last buy before pool migration sends too much ETH, refund
    // @dev    the difference.
    function _refund(uint256 id, uint256 realAmountOut, uint256 realETH, address sender) internal returns (uint256 realIn) {
        BondingCurve storage bC = getBondingCurve[id];        
        uint256 tempIn = FullMath.mulDiv(FullMath.mulDiv(realAmountOut, bC.virtualETH, (bC.virtualTokens - realAmountOut)),bC.tokenMul1,bC.tokenMul0);
        realIn = FullMath.mulDiv(tempIn, (10000 + feeOnCurve), 10000);
    }

    // @dev    Sets the fee of the buy/sells in the bonding curve.
    function setCurveFee(uint256 bps) public onlyFeeOwner {
        require((bps >= 25) && (bps <= 100),"Fee bps can only be between 25 and 100.");
        feeOnCurve = bps;
    }

    // @dev    Check if V2 Pool price has been manipulated before migration happened
    function _checkPriceManipulationV2(uint256 id) internal view returns (bool manipulation) {
        // @dev    UniswapV2Pair init hash code for SEPOLIA, MAINNET, ARBITRUM, POLYGON, BASE, UNICHAIN
        bytes32 initCodeHash = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

        address token0 = getBondingCurve[id].token0;
        address token1 = getBondingCurve[id].token1;

        (address token01, address token11) = token0 < token1 ? (token0, token1) : (token1, token0);

        address pair = address(uint160(uint256(keccak256(abi.encodePacked(
            hex'ff',
            _v2Factory,
            keccak256(abi.encodePacked(token01, token11)),
            initCodeHash
        )))));

        manipulation = ((IWETH9(token0).balanceOf(pair) > 0) || (IWETH9(token1).balanceOf(pair) > 0)) ? true : false;
    }

    // @dev    Creation of Uniswap V2 pool
    function _createV2pool(uint256 id) internal returns (address pair) {
        BondingCurve storage bC = getBondingCurve[id];
        address token0 = bC.token0;

        IWETH9(WETH).deposit{value: bC.ethPool}();

        IWETH9(WETH).approve(_v2router, type(uint256).max);
        IWETH9(token0).approve(_v2router, type(uint256).max);

        pair = v2Factory.createPair(WETH, token0);
        v2router.addLiquidity(WETH, token0, bC.ethPool, minimumTokensTransfer, 0, 0, address(0), block.timestamp);
        bC.v2pool = true;
    }

    // @dev    Check if V3 Pool price has been manipulated before migration happened
    function _checkPriceManipulationV3(uint256 id, uint24 feeAmount) internal returns (bool manipulation) {
        BondingCurve storage bC = getBondingCurve[id];
        address checkPool = v3Factory.getPool(bC.token0, WETH, feeAmount);

        if (checkPool != address(0)) {
            token0addr = Iv3Pool(checkPool).token0();
            uint160 sqrtX = (token0addr != bC.token1) ? SqrtX96Math.getSqrtPriceX96(minimumTokensTransfer, bC.ethPool, 18, 18) : SqrtX96Math.getSqrtPriceX96(bC.ethPool, minimumTokensTransfer, 18, 18);
            (uint160 sqrtPrice, , , , , , ) = Iv3Pool(checkPool).slot0();

            manipulation = (sqrtX == sqrtPrice) ? false : true;
        } else {
            manipulation = false;
        }
    }

    // @dev    Creation of the Uniswap V3 pool
    function _createV3pool(uint256 id, uint24 feeAmount) internal {
        BondingCurve storage bC = getBondingCurve[id];
        address token00 = bC.token0;
        address token11 = bC.token1;
        
        uint256 reserve0 = minimumTokensTransfer;

        IWETH9(WETH).deposit{value: bC.ethPool}();

        IWETH9(WETH).approve(_v3positionManager, type(uint256).max);
        IWETH9(token00).approve(_v3positionManager, type(uint256).max);

        address v3pool = v3Factory.createPool(token00, token11, feeAmount);
        token0addr = Iv3Pool(v3pool).token0();

        uint160 sqrtX = (token0addr != token11) ? SqrtX96Math.getSqrtPriceX96(minimumTokensTransfer, bC.ethPool, 18, 18) : SqrtX96Math.getSqrtPriceX96(bC.ethPool, minimumTokensTransfer, 18, 18);
        Iv3Pool(v3pool).initialize(sqrtX);

        (uint256 tokenId, , , ) = v3positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: (token0addr != token11) ? token00 : token11,
                token1: (token0addr != token11) ? token11 : token00,
                fee: feeAmount,
                tickLower: -getMaxTicks[feeAmount],
                tickUpper: getMaxTicks[feeAmount],
                amount0Desired: (token0addr != token11) ? minimumTokensTransfer : bC.ethPool,
                amount1Desired: (token0addr != token11) ? bC.ethPool : minimumTokensTransfer,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        bC.uniV3Id = uint64(tokenId);
    }

    // @dev    Check if Uniswap V4 Pool price has been manipulated
    function _checkPriceManipulationV4(uint256 id, uint24 setFee) internal view returns (bool manipulation) {
        BondingCurve storage bC = getBondingCurve[id];

        address token00 = address(0);
        address token11 = bC.token0;

        IUniswapV4PoolManager.PoolKey memory pool = IUniswapV4PoolManager.PoolKey({
            currency0: token00,
            currency1: token11,
            fee: setFee,
            tickSpacing: getTicks[setFee],
            hooks: address(0)
        });

        // calculate poolId

        bytes25 poolId = bytes25(keccak256(abi.encode(pool)));

        // check if tickSpacing is 0 or not

        IUniswapV4PoolManager.PoolKey memory returnedPool = V4PositionManager(v4POSM).poolKeys(poolId);

        manipulation = (returnedPool.tickSpacing != 0) ? true : false;
    }

    // @dev    Creation of the Uniswap V4 pool.
    // --
    // @dev     we create the v4 pool with native currency: ETH. No WETH.
    function _createV4pool(uint256 id, uint24 setFee) internal {
        BondingCurve storage bC = getBondingCurve[id];
        uint256 amount1 = minimumTokensTransfer; //bC.reserve0; // @dev   token reserve
        uint256 amount0 = bC.ethPool; // @dev   eth to pool

        // @dev    As we create the V4 pool with native ETH, currency0 will always be address(0),
        // @dev    as uint160(address(0)) is always 0 and other addresses are always >0.
        // @dev    Therefor a comparison if address(0) < address(x) will always result in true,
        // @dev    which proves that currency0 is always native ETH.

        address token00 = address(0);
        address token11 = bC.token0;

        uint160 sqrtPriceX96 = SqrtX96Math.getSqrtPriceX96(amount0, amount1, 18, 18);
        uint128 amount = SqrtX96Math.getLiquidityForAmounts(sqrtPriceX96, amount0, amount1, getMaxTicks[setFee]);

        IUniswapV4PoolManager.PoolKey memory pool = IUniswapV4PoolManager.PoolKey({
            currency0: token00,
            currency1: token11,
            fee: setFee,
            tickSpacing: getTicks[setFee],
            hooks: address(0)
        });

        // @dev    As we use native ETH with address(0) this will always result in token00 = ETH. We need to approve
        // @dev    the other token to permit2.
        IWETH9(token11).approve(uniPermit2, type(uint256).max);
        IAllowanceTransfer(address(uniPermit2)).approve(token11, address(v4POSM), type(uint160).max, type(uint48).max);

        //bytes memory hookData = new bytes(0);

        (bytes memory actions, bytes[] memory mintParams) =
            _mintLiquidityParams(id, pool, -getMaxTicks[setFee], getMaxTicks[setFee], amount, amount0, amount1, address(this), new bytes(0));

        bytes[] memory params = new bytes[](2);

        params[0] = abi.encodeWithSelector(V4PositionManager(v4POSM).initializePool.selector, pool, sqrtPriceX96, new bytes(0));
        params[1] = abi.encodeWithSelector(
            V4PositionManager(v4POSM).modifyLiquidities.selector, abi.encode(actions, mintParams), block.timestamp + 60
        );

        V4PositionManager(v4POSM).multicall{value: amount0}(params);
    }

    // @dev    Helper function to launch the V4 pool.

    function _mintLiquidityParams(uint256 id, IUniswapV4PoolManager.PoolKey memory poolKey, int24 _tickLower,
        int24 _tickUpper, uint256 liquidity, uint256 amount0Max, uint256 amount1Max, address recipient,
        bytes memory hookData) internal returns (bytes memory, bytes[] memory) {
            bytes memory actions = abi.encodePacked(uint8(0x02), uint8(0x0d));

            bytes[] memory params = new bytes[](2);
            params[0] = abi.encode(poolKey, _tickLower, _tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);
            params[1] = abi.encode(poolKey.currency0, poolKey.currency1);

            getBondingCurve[id].uniV4Id = uint72(V4PositionManager(v4POSM).nextTokenId());

            return (actions, params);
    }   

    // @dev   If price manipulation is detected in every Uniswap pool
    // @dev   creation, this activates automatically and deactivates
    // @dev   the pool. FeeOwner Contract can withdraw the ETH and
    // @dev   the tokens to refund them.
    // @dev   This is way safer then waiting for an exploit to happen
    // @dev   like on four meme.
    function _activateEmergencyWithdrawal(uint256 id) internal {
        getBondingCurve[id].manipulation = true;
    }

    function emergencyWithdrawal(uint256 id, address to) public onlyFeeOwner {
        require(getBondingCurve[id].manipulation, "Error: No price manipulation detected.");

        uint256 balance0 = getBondingCurve[id].reserve0;
        uint256 balance1 = getBondingCurve[id].reserve1;

        IWETH9(getBondingCurve[id].token0).transfer(to, balance0);
        payable(to).transfer(balance1);
    }

    // @dev    Migration.
    // @dev    We launch the pools as:
    // @dev    I)
    // @dev    (i)  Uniswap V4 0.5% || (ii)  Uniswap V4 0.4% || (iii)  Uniswap V4 0.3%
    // @dev    (iv) Uniswap V3 0.3% || (v)   Uniswap V3 1.0% || (vi)   Uniswap V2
    // @dev    in this order, where (iv) and (v) go to (i) and (ii) and bump the rest
    // @dev    up in the order if launch as V4 is deactivated.
    // @dev    The order of the V4 launch order can be switched around.
    // @dev    On First Launch we launch with: if V4: 0.5%, if V3: 0.3%
    // @dev    This is set already in the factory contract, so on creation of a 
    // @dev    bonding curve this will always launch as this pool, even if migration happens
    // @dev    in the far future.
    function _migrate(uint256 id) internal {
        BondingCurve storage bC = getBondingCurve[id];
        ERC20(bC.token0).transfer(feeOwner, 2000000 * 10 ** 18);
        bC.reserve0 -= 2000000 * 10 ** 18;

        // @dev Locks the reserved tokens into the FeeOwner Contract for
        // @dev 50% for 6 months and 50% for 1 year.
        FeeCollector(payable(feeOwner)).lockTokens(bC.token0, id);

        // somethings off with the reward. should bei 0.125 but on a but we got only 0.10x something
        // when the buy triggered the migrate

        /*
            new idea: 0.1 eth go to creator, and 0.1 eth to stakers if there are any, if not then 0.2 eth to creator
        */

        /*target is: 7.1 eth
        to pool: 6.9
        to staker: 0.1
        to creator: 0.1 (0.2 if nobody is staking)

        uint12*/

        _migrationSplit(bC.reserve1 - bC.ethPool, bC.creator);

        // v4 pools work with 2500, 3000, 3500, 4000, 4500, 5000, 10000 fee levels
        // v3 with 3000 and 10000
        // *how to tell in which order we want to launch? -> array
        // make to eth required changeable to account for rising/falling prices for ETH.
        // make it only changeable every 1 month
        // only do the for loop if entering into v4 check
        //
        uint256 migratedTo;
        uint256 migratedFee;
        if (bC.launchAsV4) {
            // here we try to launch as V4 first, what we want to do is enter the first if and run the loop there,
            // if all are manipulated go to v3 launch
            // do an extra function for the loop.
            if (!_v4loop(id)) {
                _createV4pool(id, v4launcher);
                migratedTo = 4; migratedFee = v4launcher;
            }
            else if (!_checkPriceManipulationV3(id, 3000)) {
                _createV3pool(id, 3000);
                migratedTo = 3; migratedFee = 3000;
            }
            else if (!_checkPriceManipulationV3(id,10000)) {
                _createV3pool(id,10000);
                migratedTo = 3; migratedFee = 10000;
            }
            else if (!_checkPriceManipulationV2(id)) {
                _createV2pool(id);
                migratedTo = 2; migratedFee = 0;
            }
            else {
                _activateEmergencyWithdrawal(id);
                migratedTo = 0; migratedFee = 0;
            }
        } else {
            if (!_checkPriceManipulationV3(id, 3000)) { // test
                _createV3pool(id, 3000);
                migratedTo = 3; migratedFee = 3000;
            }
            else if (!_checkPriceManipulationV3(id, 10000)) {  // test
                _createV3pool(id, 10000);
                migratedTo = 3; migratedFee = 10000;
            }
            else if (!_checkPriceManipulationV2(id)) { // test
                _createV2pool(id);
                migratedTo = 2; migratedFee = 0;
            }
            else if (!_v4loop(id)) {
                _createV4pool(id, v4launcher);
                migratedTo = 4; migratedFee = v4launcher;
            }
            else { // test
                _activateEmergencyWithdrawal(id);
                migratedTo = 0; migratedFee = 0;
            }
        }

        emit Migrate(id, bC.token0, address(0), minimumTokensTransfer, bC.ethPool, migratedTo, migratedFee);
    }

    function _v4loop(uint256 id) internal returns (bool manipulation) {
        manipulation = true;

        for (uint8 i = 0; i < v4orderArray.length; i++) {
            uint24 feeLevel = uint24(v4orderArray[i]) * uint24(100);
            // @dev    We need to multiply the v4orderArray by 100 as we use uint8.
            if (!_checkPriceManipulationV4(id, feeLevel/*uint24(v4orderArray[i]) * 100)*/)) {
                manipulation = false;
                v4launcher = feeLevel;//uint24(v4orderArray[i]) * 100;
                // where to return the fee which is ok to launch?
                // just save it into a global value.
                break;
            }
        }

        // @dev    If for loop runs fully through manipulation = false
        // @dev    never gets set, i.e. true is returned.
        // @dev    If no manipulation is detected, break the loop and
        // @dev    return which fee level is ok to launch.
    }

    function v4order(uint8[7] memory instruction) public onlyFeeOwner {
        // check if every entry divided by 500 is 0 (a % b)
        for (uint256 i = 0; i < instruction.length; i++) {
            require(instruction[i] % 5 == 0, "Error: You can only set 25, 30, 35, 40, 45, 50, and 100 as valid fee levels.");
            require(((instruction[i] >= 25) && (instruction[i] <= 50)) || (instruction[i] == 100), "Error: You can only set 25, 30, 35, 40, 45, 50, and 100 as valid fee levels.");
            v4orderArray[i] = instruction[i];
        }
    }

    // @dev    This lets the FeeOwner Contract claim the collected fees on Uniswap V3/V4.
    // @dev    Reverts if a Uniswap V2 pool got created due price manipulations.
    function claim(uint256 id) external onlyFeeOwner returns (address _token0, address _token1) {
        BondingCurve storage bC = getBondingCurve[id];
        require(bC.migrated, "Error: Pool has not yet migrated.");
        require(!bC.v2pool, "Error: Pool is Uniswap V2.");

        // @dev   This claims on V4
        if (bC.uniV4Id > 0) {
            bytes memory hookData = new bytes(0);
            bytes memory actions = abi.encodePacked(uint8(0x01), uint8(0x11));
            bytes[] memory params = new bytes[](2);
            params[0] = abi.encode(bC.uniV4Id, 0, 0, 0, hookData);
            address currency0 = address(0);
            address currency1 = bC.token0;
            params[1] = abi.encode(currency0, currency1, feeOwner);

            uint256 deadline = block.timestamp + 60;

            V4PositionManager(v4POSM).modifyLiquidities(
                abi.encode(actions, params),
                deadline
            );

            _token1 = currency0;
            _token0 = currency1; // returns always token0 as the token, and 1 as eth/weth

        // @dev   This claims on V3
        } else {
            INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
                    tokenId: bC.uniV3Id,
                    recipient: feeOwner,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
            });

            uint256 before = IWETH9(WETH).balanceOf(address(this));  
            v3positionManager.collect(params);
            uint256 aftr = IWETH9(WETH).balanceOf(address(this));
            uint256 WETHAmount = aftr - before;

            _token0 = bC.token0;
            _token1 = address(0);

            IWETH9(WETH).withdraw(WETHAmount);
            payable(feeOwner).transfer(WETHAmount);
            IWETH9(_token0).transfer(feeOwner, IWETH9(bC.token0).balanceOf(address(this)));
        }
    }
}