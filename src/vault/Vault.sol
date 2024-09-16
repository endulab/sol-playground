// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * This smart contract implements a Vault for eth, ERC20 and ERC721 tokens.
 * There is no need to use SafeMath in Solidity 0.8.x
 */
contract Vault is IERC721Receiver {
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(address => uint) ethBalances;
    mapping(bytes32 => uint) erc20Balances;
    mapping(bytes32 => EnumerableSet.UintSet) erc721Balances;

    event DepositEth(address indexed sender, uint value);
    event WithdrawEth(address indexed sender, uint value);
    event DepositERC20(address indexed sender, address indexed erc20Address, uint value);
    event WithdrawERC20(address indexed sender, address indexed erc20Address, uint value);
    event DepositERC721(address indexed sender, address indexed erc721Address, uint tokenId);
    event WithdrawERC721(address indexed sender, address indexed erc721Address, uint tokenId);

    error Vault_DepositEthValueTooLow();
    error Vault_ValueToWithdrawIncorrect();
    error Vault_NotEnoughEthBalance();
    error Vault_EthTransferError();
    
    error Vault_DepositERC20ValueTooLow();
    error Vault_ERC20BalanceTooLow();
    error Vault_ERC20TransferError();
    error Vault_NotEnoughERC20Balance();

    error Vault_DepositERC721ValueTooLow();
    error Vault_ERC721TokenAlreadyAdded(uint tokenId);
    error Vault_ERC721TokenNotFound(uint tokenId);
    error Vault_ERC721TokenIndexOutOfBounds();

    // Returns account's eth balance in vault
    function ethBalanceOf(address account) external view returns (uint) {
        return ethBalances[account];
    }

    // Returns account's ERC20 balance in vault
    function erc20BalanceOf(address account, address erc20ContractAddress) external view returns (uint) {
        bytes32 key = prepareERCKey(account, erc20ContractAddress);
        return erc20Balances[key];
    }

    // Returns the number of account's ERC721 tokens in vault
    function erc721BalanceOf(address account, address erc721ContractAddress) external view returns (uint) {
        bytes32 key = prepareERCKey(account, erc721ContractAddress);
        return erc721Balances[key].length();
    }

    // Returns account's ERC721 token id with index
    function erc721TokenAtIndex(address account, address erc721ContractAddress, uint index) external view returns (uint) {
        bytes32 key = prepareERCKey(account, erc721ContractAddress);
        if (index >= erc721Balances[key].length()) {
            revert Vault_ERC721TokenIndexOutOfBounds();
        }
        return erc721Balances[key].at(index);
    }
   
    function depositEth() public payable {
        if (msg.value == 0) {
            revert Vault_DepositEthValueTooLow();
        }

        ethBalances[msg.sender] += msg.value;
        emit DepositEth(msg.sender, msg.value);
    }

    function withdrawEth(uint value) public {
        if (value == 0) {
            revert Vault_ValueToWithdrawIncorrect();
        }
        if (value > ethBalances[msg.sender]) {
            revert Vault_NotEnoughEthBalance();
        }

        ethBalances[msg.sender] -= value;
        emit WithdrawEth(msg.sender, value);

        (bool success, ) = msg.sender.call{value: value}("");
        if (!success) {
            revert Vault_EthTransferError();
        }
    }

    function depositERC20(address erc20ContractAddress, uint value) public {
        if (value == 0) {
            revert Vault_DepositERC20ValueTooLow();
        }
        IERC20 erc20Contract = IERC20(erc20ContractAddress);
        if (erc20Contract.balanceOf(msg.sender) < value) {
            revert Vault_ERC20BalanceTooLow();
        }

        bytes32 key = prepareERCKey(msg.sender, erc20ContractAddress);
        erc20Balances[key] += value;
        emit DepositERC20(msg.sender, erc20ContractAddress, value);

        bool success = erc20Contract.transferFrom(msg.sender, address(this), value);
        if (!success) {
            revert Vault_ERC20TransferError();
        }
    }

    function withdrawERC20(address erc20ContractAddress, uint value) public {
        if (value == 0) {
            revert Vault_ValueToWithdrawIncorrect();
        }
        bytes32 key = prepareERCKey(msg.sender, erc20ContractAddress);
        if (value > erc20Balances[key]) {
            revert Vault_NotEnoughERC20Balance();
        }

        erc20Balances[key] -= value;
        emit WithdrawERC20(msg.sender, erc20ContractAddress, value);

        bool success = IERC20(erc20ContractAddress).transfer(msg.sender, value);
        if (!success) {
            revert Vault_ERC20TransferError();
        }
    }

    function depositERC721(address erc721ContractAddress, uint[] calldata tokenIds) public {
        if (tokenIds.length == 0) {
            revert Vault_DepositERC721ValueTooLow();
        }

        bytes32 key = prepareERCKey(msg.sender, erc721ContractAddress);
        for (uint i = 0; i < tokenIds.length; i++) {
            bool success = erc721Balances[key].add(tokenIds[i]);
            if (!success) {
                revert Vault_ERC721TokenAlreadyAdded(tokenIds[i]);
            }
            emit DepositERC721(msg.sender, erc721ContractAddress, tokenIds[i]);

            IERC721(erc721ContractAddress).safeTransferFrom(msg.sender, address(this), tokenIds[i]);
        }
    }

    function withdrawERC721(address erc721ContractAddress, uint[] calldata tokenIds) public {
        if (tokenIds.length == 0) {
            revert Vault_ValueToWithdrawIncorrect();
        }
        bytes32 key = prepareERCKey(msg.sender, erc721ContractAddress);
        
        for (uint i = 0; i < tokenIds.length; i++) {
            bool success = erc721Balances[key].remove(tokenIds[i]);
            if (!success) {
                revert Vault_ERC721TokenNotFound(tokenIds[i]);
            }
            emit WithdrawERC721(msg.sender, erc721ContractAddress, tokenIds[i]);

            IERC721(erc721ContractAddress).safeTransferFrom(address(this), msg.sender, tokenIds[i]);
        }
    }

    function prepareERCKey(address account, address erc20ContractAddress) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, erc20ContractAddress));
    }

    // Required by IERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
