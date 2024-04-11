// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.6;

interface ITokenStandardConverter
{
    event ERC223WrapperCreated(address indexed _token, address indexed _ERC223Wrapper);
    event ERC20WrapperCreated(address indexed _token, address indexed _ERC20Wrapper);

    function getERC20WrapperFor(address _token) external view returns (address, string memory);
    function getERC223WrapperFor(address _token) external view returns (address, string memory);
    function getERC20OriginFor(address _token) external view returns (address);

    function getERC223OriginFor(address _token) external view returns (address);
    function predictWrapperAddress(address _token, bool _isERC20) view external returns (address);

    function tokenReceived(address _from, uint _value, bytes memory _data) external returns (bytes4);

    function createERC223Wrapper(address _token) external returns (address);
    function createERC20Wrapper(address _token) external returns (address);
    function depositERC20(address _token, uint256 _amount) external returns (bool);
    function wrapERC20toERC223(address _ERC20token, uint256 _amount) external returns (bool);
    function unwrapERC20toERC223(address _ERC20token, uint256 _amount) external returns (bool);
    function isWrapper(address _token) external view returns (bool);
    function rescueERC20(address _token) external;
    function transferOwnership(address _newOwner) external;
}
