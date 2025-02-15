// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./MultiSigWallet.sol";  

contract BoardFundManagerFactory {
    event FundManagerDeployed(address indexed newFund, address indexed token, address[] boardMembers);

    address[] public deployedFunds;

    function createFundManager(address[] memory _members, address _token) external {
        BoardFundManager newFund = new BoardFundManager(_members, _token);
        deployedFunds.push(address(newFund));
        emit FundManagerDeployed(address(newFund), _token, _members);
    }

    function getDeployedFunds() external view returns (address[] memory) {
        return deployedFunds;
    }
}
