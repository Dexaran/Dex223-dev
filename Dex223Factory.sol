// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IDex223Factory.sol';

import './interfaces/ITokenConverter.sol';
import './interfaces/ITokenStandardIntrospection.sol';

import './Dex223PoolDeployer.sol';
import './NoDelegateCall.sol';

import './Dex223Pool.sol';

/// @title Canonical Uniswap V3 factory
/// @notice Deploys Uniswap V3 pools and manages ownership and control over pool protocol fees
contract Dex223Factory is IDex223Factory, UniswapV3PoolDeployer, NoDelegateCall {
    // @inheritdoc IUniswapV3Factory
    address public override owner;

    address public pool_lib;

    ITokenStandardIntrospection public standardIntrospection;
    address public tokenReceivedCaller;

    ITokenStandardConverter public converter;
    //ITokenStandardConverter converter = ITokenStandardConverter(0x08b9DfA96d4997b460dFEb1aBb994a7279dDb420);

    // @inheritdoc IUniswapV3Factory
    mapping(uint24 => int24) public override feeAmountTickSpacing;
    // @inheritdoc IUniswapV3Factory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    constructor() {
        owner = msg.sender;
        converter = ITokenStandardConverter(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4); // Just some test address. Replace with a mainnet ERC-7417 converter instead!
        emit OwnerChanged(address(0), msg.sender);
        feeAmountTickSpacing[500] = 10;
        emit FeeAmountEnabled(500, 10);
        feeAmountTickSpacing[3000] = 60;
        emit FeeAmountEnabled(3000, 60);
        feeAmountTickSpacing[10000] = 200;
        emit FeeAmountEnabled(10000, 200);
    }

    function tokenReceived(address _from, uint _value, bytes memory _data) public returns (bytes4)
    {
        if(_from == address(this) && _value == 0)
        {
            tokenReceivedCaller = msg.sender;
        }
        return 0x8943ec02;
    }

    // @inheritdoc IUniswapV3Factory
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override noDelegateCall returns (address pool) {
        require(tokenA != tokenB);
        (address _token0_erc20, address _token0_erc223, uint8 _token0_standard) = identifyTokens(tokenA);
        (address _token1_erc20, address _token1_erc223, uint8 _token1_standard) = identifyTokens(tokenB);
        //(address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if(_token0_erc20 > _token1_erc20)
        {
            // Make sure token0 < token1 ERC-20-wise.
            tokenA = _token0_erc20;
            _token0_erc20 = _token1_erc20;
            _token1_erc20 = tokenA;

            tokenA = _token0_erc223;
            _token0_erc223 = _token1_erc223;
            _token1_erc223 = tokenA;
        }

        require(_token0_erc20 != address(0));
        int24 tickSpacing = feeAmountTickSpacing[fee];
        require(tickSpacing != 0);
        require(getPool[_token0_erc20][_token1_erc20][fee] == address(0));
        pool = deploy(address(this), _token0_erc20, _token1_erc20, _token0_erc223, _token1_erc223, fee, tickSpacing);
        Dex223Pool(pool).set(_token0_erc20, _token1_erc20, _token0_erc223, _token1_erc223, fee, tickSpacing);
        getPool[_token0_erc20][_token1_erc20][fee] = pool;
        // populate mapping in ALL directions.
        getPool[_token1_erc20][_token0_erc20][fee] = pool;
        getPool[_token0_erc20][_token1_erc223][fee] = pool;
        getPool[_token1_erc20][_token0_erc223][fee] = pool;
        getPool[_token0_erc223][_token1_erc20][fee] = pool;
        getPool[_token0_erc223][_token1_erc223][fee] = pool;
        getPool[_token1_erc223][_token0_erc223][fee] = pool;
        getPool[_token1_erc223][_token0_erc20][fee] = pool;
        emit PoolCreated(_token0_erc20, _token1_erc20, _token0_erc223, _token1_erc223, fee, tickSpacing, pool);
        tokenReceivedCaller = address(0);
    }

    // @inheritdoc IUniswapV3Factory
    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    function identifyTokens(address _token) internal returns (address erc20_address, address erc223_address, uint8 origin)
    {
        // origin      << address of the token origin (always exists)
        // originERC20 << if the origins standard is ERC20 or not
        // converted   << alternative version that would be created via ERC-7417 converter, may not exist
        //                can be predicted as its created via CREATE2

        // Not using the standard introspection now but better check it for safety in production.
        bytes memory erc223_output = bytes("0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000033232330000000000000000000000000000000000000000000000000000000000");

        // Check the provided token's standards.
        if(converter.isWrapper(_token))
        {
            // Trust the converter.
            // If the token is a wrapper for something then we know for sure it has an alternative (origin) version
            // and the origins version is the opposite of the provided tokens version.
            // Ask the token if its ERC-223 as the converter always implements "standard()" function in its ERC-223 wrappers
            // and if the response is "223" then the provided token is certainly ERC-223,
            // otherwise its certainly ERC-20.

            (bool success, bytes memory data) =
                _token.staticcall(abi.encodeWithSelector(0x5a3b7e42)); // Call the "standard()" func of ERC-223 token
                                                                       // If it fails then the token is ERC-20.
            if(success /*&& data == erc223_output*/ ) 
            {
                return (converter.getERC20OriginFor(_token), _token, 20);
            }
            else
            {
                return (_token, converter.getERC223OriginFor(_token), 223);
            }
        }
        else 
        {
            // If the token is not a wrapper according to the converter then we have to test it.
            // First call the "standard()" function
            (bool success, bytes memory data) =
                _token.staticcall(abi.encodeWithSelector(0x5a3b7e42));
                if(success && data.length == erc223_output.length)
                {
                    // Solidity does not know how to compare strings... so we have to do the manual labour.
                    for(uint32 i = 0; i < data.length; i++)
                    {
                        if(data[i] != erc223_output[i]) success = false; // Use existing variable to avoid "stack too deep" error.
                    }
                    if(success)
                    {
                        // If `success` is still true then the provided token replied that it is ERC-223
                        // and it is not a wrapper according to the converter.
                        return (converter.predictWrapperAddress(_token, false), _token, 223);
                    }
                    else
                    {
                        // The `standard` func call succeeded but we have no idea which token it is.
                        // It could happen if the token contract contained a permissive fallback function
                        // for example in case the token contract is merged with the ICO contract
                        // which was selling that token and had a permissive fallback function implemented.
                        // Continue the investigation in this case.
                    }
                }

            // If the `standard` func call failed or succeeded but didnt return "223" then the token can be either
            // a ERC-223 which does not implement `standard` func properly
            // or a standard ERC-20.
            // Test it via the `transfer()` function call then. ERC-20 `transfer` calls MUST allow zero transfers,
            // ERC-223 `transfer` calls MAY allow zero transfers and MUST invoke `tokenReceived` in case
            // they do allow zero transfers.
            // There are plenty of tokens which improperly implement ERC-20 standard however, for example
            // the most infamous USDT is not compatible with the ERC-20 standard as per its documentation
            // so we have to deal with it via low level calls.
            
            (bool transfer_success, bytes memory transfer_data) =
                _token.call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, address(this), 0));
                if(transfer_success)
                {
                    if(tokenReceivedCaller == address(0))
                    {
                        // If the transfer succeeded and the tokenReceivedCaller is not the address of the _token
                        // then the function transfer was executed as if it is ERC-20 and it doesn't invoke 
                        // tokenReceived() on trasnfer so the token is certainly ERC-20.
                        return (_token, converter.predictWrapperAddress(_token, true), 20);
                    }
                    else if(tokenReceivedCaller == _token)
                    {
                        // If the transfer succeeded and the tokenReceivedCaller is _token address
                        // then the tokenReceived func was properly invoked
                        // and the _token is certainly a ERC-223 token.
                        return (converter.predictWrapperAddress(_token, false), _token, 223);
                    }
                }
                else 
                {
                    // So the zero transfer failed and we still have no idea which standard the token implements.
                    // The final argument here is actually how the `transfer` of non-zero values are performed:
                    // - if it invokes `tokenReceived` in the destination contract then its certainly ERC-223
                    // - otherwise its certainly ERC-20.
                    // Therefore we need to transfer 1 WEI of a token to some contract and then ask it
                    // whether the `tokenReceived` function was invoked upon our transfer or not.
                    // (And may be nicely ask it to send the transferred 1 WEI of a token back)

                    // In order to be able to transfer tokens someone has to deposit at least 1 WEI of the _token
                    // to the Factory address first.

                    IERC20Minimal(_token).transfer(address(standardIntrospection), 1);

                    // Now if the depositAmount(_token) of the standardIntrospection is non-zero
                    // then the deposited token was recorded via the tokenReceived func
                    // and tokenA is ERC-223.
                    // Otherwise tokenA is certainly ERC-20.
                    if(standardIntrospection.depositedAmount(_token) != 0)
                    {
                        return (converter.predictWrapperAddress(_token, false), _token, 223);
                    }
                    else 
                    {
                        return (_token, converter.predictWrapperAddress(_token, true), 20);
                    }
                }
        }
    }
    

    // @inheritdoc IUniswapV3Factory
    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
        /*  COMMENTED FOR TESTING PURPOSES
        require(msg.sender == owner);
        require(fee < 1000000);
        // tick spacing is capped at 16384 to prevent the situation where tickSpacing is so large that
        // TickBitmap#nextInitializedTickWithinOneWord overflows int24 container from a valid tick
        // 16384 ticks represents a >5x price change with ticks of 1 bips
        require(tickSpacing > 0 && tickSpacing < 16384);
        require(feeAmountTickSpacing[fee] == 0);

        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
        */
    }
}

contract PoolAddressHelper
{
    function getPoolCreationCode() public view returns (bytes memory) {
        return type(Dex223Pool).creationCode;
    }
    
    function hashPoolCode(bytes memory creation_code) public view returns (bytes32 pool_hash){
        pool_hash = keccak256(creation_code);
    }
    
    function computeAddress(address factory, 
                            address tokenA,
                            address tokenB,
                            uint24 fee) 
                            external view returns (address _pool) 
    {
        require(tokenA < tokenB, "token1 > token0");
        //---------------- calculate pool address
            bytes32 _POOL_INIT_CODE_HASH  = hashPoolCode(getPoolCreationCode());
            bytes32 pool_hash = keccak256(
            abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encode(tokenA, tokenB, fee)),
                _POOL_INIT_CODE_HASH
            )
            );
            bytes20 addressBytes = bytes20(pool_hash << (256 - 160));
            _pool = address(uint160(addressBytes));
    }
}
