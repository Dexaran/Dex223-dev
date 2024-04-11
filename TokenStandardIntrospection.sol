// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

contract TokenStandardIntrospection {
    mapping (address => uint256) public erc223Deposits;
    
    function tokenReceived(address _from, uint _value, bytes memory _data) public returns (bytes4)
    {
        erc223Deposits[msg.sender] = _value;
        return 0x8943ec02;
    }

    function depositedAmount(address _token) view external returns (uint256)
    {
        return erc223Deposits[_token];
    }
}
