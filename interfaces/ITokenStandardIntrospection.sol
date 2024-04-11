// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

interface ITokenStandardIntrospection {
    function tokenReceived(address _from, uint _value, bytes memory _data) external returns (bytes4);
    function depositedAmount(address _token) view external returns (uint256);
}
