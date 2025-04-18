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
 * LFG.CLUB FACTORY CONTRACT
 *
 */

// SPDX-License-Identifier: LicenseRef-LFG-Commercial
// Full license: https://github.com/lfgclub/lfgclub/blob/main/LICENSE
pragma solidity ^0.8.29;

import "./standardERC20.sol";
import "./pool.sol";
import "./feeAccount.sol";
import "./depositContract.sol";
import "./metadata.sol";

contract Factory {
    LFGClubToken public latestDeployedToken;
    address public constant WETH9 = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

    address public immutable creator;

    // @dev    Uniswap V3 Factory Address
    address public constant _v3Factory = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;
    // @dev    Uniswap V3 NFT Manager Address
    address public constant _v3positionManager = 0x1238536071E1c677A632429e3655c799b22cDA52;

    uint256 public tokenID = 1;

    address public immutable feeOwner;

    address public _poolAddress;
    address public _depositAddress;

    address public _nativeAddress;

    uint256 _lastDepositChange;
    bool _upgradeOff;

    bool offline;

    modifier onlyFeeOwner() {
        require(feeOwner == msg.sender, "NOT_OWNER");
        _;
    }

    modifier onlyCreator() {
        require(creator == msg.sender, "NOT_CREATOR");
        _;
    }

    struct TokenInfo {
        address tokenAddress;
        uint48 creationBlock;
        uint48 updateBlock;
    }

    mapping(uint256 _tokenID => TokenInfo) public _tokenAddress; 
    mapping(uint256 _tokenID => uint256) public lastMetaUpdate;  

    event CreateToken(bytes32 indexed metadataHash, address indexed token, uint256 indexed tokenId, string name, string symbol, string description, string image, string web, string twitter, string telegram);
    event UpdateMetadata(bytes32 indexed unused, address indexed token, uint256 indexed tokenId, string description, string image, string web, string twitter, string telegram);

    constructor() {
        feeOwner = address(new FeeCollector(address(this), msg.sender, WETH9, _v3Factory, _v3positionManager));
        offline = false;
        creator = msg.sender;
    }

    // @dev    We need to deploy the pool contract seperately because of init bytecode restrictions.
    // @dev    Set the poolAddress here.
    function setPoolAddress(address pool) public onlyCreator {
        require(_poolAddress == address(0), "POOL_ALREADY_SET");
        _poolAddress = pool;
    }

    // @dev    We calculate the keccak256 hash here to generate a unique hash that is associated with the
    // @dev    initial parameters that are provided during token creation. This is done in order to
    // @dev    make initial parameters fraud proof.
    function calculateHash(uint256 id, string[7] memory _meta) internal pure returns (bytes32) {
        return Metadata.calculateHash(id, _meta);
    }

    // @dev   Splits the amount between feeOwner and depositors.
    function _split(uint256 amount) internal {
        uint256 split = 0;
        uint256 amnt = 0;
        // @dev   Check if somebody has deposited
        if (_depositAddress != address(0)) {
            uint256 totS = depositor(payable(_depositAddress)).totalDepositors();
            uint256 splT = depositor(payable(_depositAddress)).getSplit();
            if ((totS > 0) && (splT > 0)) {
                split = splT;
            }
        }

        if (split > 0) {
        amnt = (amount)/10000 * split;
        (bool success, ) = payable(_depositAddress).call{value: amnt}("");
        require(success, "TX_FAIL");
        }
        payable(feeOwner).transfer(amount - amnt);
    }

    // @dev    Lets the creator update the metadata or the community, on community takeover. This metadata update will only
    // @dev    happen on the webpage, on-chain the old metadata hash will always be the real one. On the webpage the old
    // @dev    metadata will still be listed on "Show raw metadata".
    // @dev    This has a fix cost. For original creator 0.05 ETH or 0.2 BNB. For a community takeover the cost is
    // @dev    0.25 ETH or 1 BNB. The cost is that high to deter bots / scammers from abusing it. This will happen
    // @dev    automatically without oversight. We can enforce higher values if called via website.
    // @dev    feeOwner can update Metadata for free (use this if there are some shenanigans...).

    function _updateMetadata(uint256 id, string[5] memory metad) public payable {
        ThePool.BondingCurve memory bc = ThePool(payable(_poolAddress)).getBondingCurve(id);

        address crtr = bc.creator;
        uint256 eTP = ThePool(payable(_poolAddress)).ethToPool();
        uint256 required = 0.005 * 10 ** 18;
        // @dev this lowers/highers the amount if certain USD/ETH is reached.
        if (eTP >= 0.69 * 10 ** 18) {
            required = 0.005 * (10 ** 18);            
        } else if (eTP >= 0.42 * 10 ** 18) {
            required = 0.003 * (10 ** 18);              
        } else if (eTP >= 0.21 * 10 ** 18) {
            required = 0.002 * (10 ** 18);
        } else {
            required = 0.005 * (10 ** 18);            
        }
        // @dev   Token creator
        if (msg.sender == crtr) {
            require(id > 0);
            require((lastMetaUpdate[id] + 7 minutes) <= block.timestamp, "WAIT_7_DAYS");  //----!! testnet: 7min // mainnet: 7 days
            require(msg.value >= required, "FEE_TOO_LOW");
            emit UpdateMetadata(0, address(0), id, metad[0], metad[1], metad[2], metad[3], metad[4]);
            _tokenAddress[id].updateBlock = uint48(block.number);
            lastMetaUpdate[id] = block.timestamp;
            _split(msg.value);
        // @dev   FeeOwner               
        } else if (msg.sender == feeOwner) {
            emit UpdateMetadata(0, address(0), id, metad[0], metad[1], metad[2], metad[3], metad[4]);
            _tokenAddress[id].updateBlock = uint48(block.number);
            lastMetaUpdate[id] = block.timestamp;
        // @dev   Community
        } else {
            require(id > 0);
            require((lastMetaUpdate[id] + 7 minutes) <= block.timestamp, "WAIT_7_DAYS");  //----!! testnet: 7min // mainnet: 7 days
            require(msg.value >= (required*700/200), "FEE_TOO_LOW");
            emit UpdateMetadata(0, address(0), id, metad[0], metad[1], metad[2], metad[3], metad[4]);
            _tokenAddress[id].updateBlock = uint48(block.number);
            lastMetaUpdate[id] = block.timestamp;
            _split(msg.value);
        }
    }

    // @dev    Resets Metadata on the website to the one it was created with it. Only use if detected abuse.
    function _resetMetadata(uint256 id) public onlyFeeOwner {
        _tokenAddress[id].updateBlock = 0;
    }

    // @dev    Create Token function.
    function createToken(string memory name, string memory symbol, string[5] memory metad) public payable returns (uint256 id) {
        require(!offline,"DEACTIVATED");

        tokenID += 1;
        id = tokenID-1;

        bytes32 tempHash = calculateHash(id, [name, symbol, metad[0], metad[1], metad[2], metad[3], metad[4]]);

        latestDeployedToken = new LFGClubToken(name, symbol, tempHash, address(this), id);
        address _token = address(latestDeployedToken);

        _tokenAddress[id].tokenAddress = address(_token);
        _tokenAddress[id].creationBlock = uint48(block.number);

        ThePool(payable(_poolAddress)).create(id, msg.sender, _token);

        emit CreateToken(tempHash, _token, id, name, symbol, metad[0], metad[1], metad[2], metad[3], metad[4]);

        if (msg.value > 0) {
            ThePool(payable(_poolAddress)).buy{value: msg.value}(id, 0);    
        }
    }

    function update(bool flag) public onlyFeeOwner {
        offline = flag;
    }

    function getLatestTokenAddress() public view returns (address) {
        return address(latestDeployedToken);
    }

    // @dev    Set metadata for native token. n0 and n1 are fallbacks if token bridge doesn't have name() and symbol() functions.
    function setNative(address _address, string[5] memory metad, string memory n0, string memory n1) public onlyCreator {
        require(_nativeAddress == address(0), "NATIVE_SET");  
        _nativeAddress = _address;
        _tokenAddress[0].tokenAddress = address(_address);
        _tokenAddress[0].creationBlock = uint48(block.number);

        string memory sy = (bytes(n0).length == 0) ? IERC20Metadata(_address).symbol() : n0;
        string memory nm = (bytes(n1).length == 0) ? IERC20Metadata(_address).name() : n1;

        bytes32 tempHash = calculateHash(0, [nm, sy, metad[0], metad[1], metad[2], metad[3], metad[4]]);

        emit CreateToken(tempHash, _address, 0, nm, sy, metad[0], metad[1], metad[2], metad[3], metad[4]);        
        if (block.chainid == 1) { // change to mainnet
            require(ERC20(_nativeAddress)._factoryAddress() == address(this),"NATIVE_INCORRECT_FACTORY");
        }
    }

    function setDepositor(address _address) public onlyCreator {
        require(_depositAddress == address(0), "DEPOSITOR_SET");  
        _depositAddress = _address;    
        require(depositor(payable(_depositAddress)).token() == _nativeAddress,"DEPOSITOR_INCORRECT_NATIVE");
        require(depositor(payable(_depositAddress)).factory() == address(this),"DEPOSITOR_INCORRECT_FACTORY");
        ThePool(payable(_poolAddress))._setDepositor();
        _lastDepositChange = block.timestamp;
    }

    // @dev    This makes the staking address upgradable if a new contract version is deployed.
    // @dev    To prevent abuse this has a 6 month cooldown, even after initial staking address set.
    // @dev    Upgradeability can be renounced.
    function upgradeDepositor(address _address) public onlyCreator {
        require(_depositAddress != address(0), "DEPOSITOR_NOT_SET");
        require((_lastDepositChange + 60 minutes) <= block.timestamp,"WAIT_12_MONTHS");   //----!! testnet: 60 min // mainnet: 366 days
        require(!_upgradeOff,"UPGRADE_RENOUNCED");
        _depositAddress = _address;    
        // @dev    This prevents that a non-contract can be set.
        require(depositor(payable(_depositAddress)).token() == _nativeAddress,"DEPOSITOR_INCORRECT_NATIVE");
        ThePool(payable(_poolAddress))._setDepositor();
        _lastDepositChange = block.timestamp;
    }

    // @dev    Permanently deactives the ability to upgrade the staking address.
    function renounceUpgrade() public onlyCreator {
        _upgradeOff = true;
    }
}