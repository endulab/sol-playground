// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * This smart contract implements a one-time agreement between buyer and seller.
 * It incorporates also arbitrator, who can resolve disputes.
 * Flow:
 *   1. Setup agreement with setAgreementEth or setAgreementERC20.
 *   2. After 1 hour the agreement is ready to be completed.
 *   3. Before completion the agreement can be disputed by seller or buyer.
 *   4. Disputed agreement can be completed by arbitrator only.
 */
contract Agreements {

    using SafeERC20 for IERC20;
    
    uint256 public agreementBalance;
    uint256 _startTime; // starting time of the agreement setup
    address public erc20Address; // address is 0 for eth

    address immutable public arbitrator;
    address immutable public buyer;
    address immutable public seller;

    enum AgreementState {
        NoAgreement,
        AgreementSet,
        AgreementDisputed,
        AgreementCompleted
    }

    AgreementState agreementState; // keeps current agreement state

    uint256 constant AGREEMENT_PERIOD = 1 hours; // agreement can be completed after the period

    event AgreementSetWithETH(address indexed buyer, uint256 amount);
    event AgreementSetWithERC20(address indexed buyer, address indexed erc20Address, uint256 amount);
    event AgreementCompleted();
    event DisputeRaisedBy(address indexed account);

    error Agreements_IncorrectAddress();
    error Agreements_EthValueIsZero();
    error Agreements_ERC20ValueIsZero();
    error Agreements_NotEnoughERC20();
    error Agreements_NotABuyer();
    error Agreements_NotAnArbitrator();
    error Agreements_EthTransferError();
    error Agreements_AgreementInWrongState(AgreementState state);
    error Agreements_PeriodNotReached();
    error Agreements_DisputeRaisedByNonAuthorizedAccount();

    modifier onlyBuyer() {
        if (msg.sender != buyer) {
            revert Agreements_NotABuyer();
        }
        _;
    }

    modifier neededState(AgreementState _state) {
        if (_state != agreementState) {
            revert Agreements_AgreementInWrongState(agreementState);
        }
        _;
    }

    constructor(address _arbitrator , address _buyer, address _seller) {
        if (_arbitrator == address(0) || _buyer == address(0) || _seller == address(0)) {
            revert Agreements_IncorrectAddress();
        }
        arbitrator = _arbitrator;
        buyer = _buyer;
        seller = _seller;
        agreementState = AgreementState.NoAgreement;
    }

    // Setups agreement. Buyer pays for the item in Ether.
    function setAgreementEth() payable public onlyBuyer() neededState(AgreementState.NoAgreement) {
        if (msg.value == 0) {
            revert Agreements_EthValueIsZero();
        }

        agreementBalance = msg.value;
        _startTime = block.timestamp;
        agreementState = AgreementState.AgreementSet;
        emit AgreementSetWithETH(msg.sender, msg.value);
    }

    // Setups agreement. Buyer pays for the item in ERC20.
    function setAgreementERC20(address erc20Addr, uint256 value) public onlyBuyer() neededState(AgreementState.NoAgreement) {
        if (value == 0) {
            revert Agreements_ERC20ValueIsZero();
        }
        IERC20 erc20Contract = IERC20(erc20Addr);
        if (erc20Contract.balanceOf(msg.sender) < value) {
            revert Agreements_NotEnoughERC20();
        }

        agreementBalance = value;
        _startTime = block.timestamp;
        agreementState = AgreementState.AgreementSet;
        erc20Address = erc20Addr;
        emit AgreementSetWithERC20(msg.sender, erc20Addr, value);

        erc20Contract.safeTransferFrom(msg.sender, address(this), value);
    }

    //! Completes agreement. Eth or ERC20 is transferred to the seller.
    function completeAgreement() external neededState(AgreementState.AgreementSet) {
        if (block.timestamp < _startTime + AGREEMENT_PERIOD) {
            revert Agreements_PeriodNotReached();
        }

        agreementState = AgreementState.AgreementCompleted;
        emit AgreementCompleted();
        
        _transferEthOrERC20(seller);
    }

    //! Raises dispute. Only buyer or seller can execute it. Agreement can be resolved only by the arbitrator.
    function raiseDispute() external neededState(AgreementState.AgreementSet) {
        if (msg.sender != buyer && msg.sender != seller) {
            revert Agreements_DisputeRaisedByNonAuthorizedAccount();
        }
        agreementState = AgreementState.AgreementDisputed;
        emit DisputeRaisedBy(msg.sender);
    }

    //! Resolves dispute. Only arbitrator can do this. Assets are transferred according to favorBuyer parameter.
    function resolveDispute(bool favorBuyer) external neededState(AgreementState.AgreementDisputed){
        if (msg.sender != arbitrator) {
            revert Agreements_NotAnArbitrator(); 
        }

        agreementState = AgreementState.AgreementCompleted;

        if (favorBuyer) {
            _transferEthOrERC20(buyer);
        } else {
            _transferEthOrERC20(seller);
        }
    }

    function _transferEthOrERC20(address to) private {
        if (erc20Address != address(0)) {
            IERC20 erc20Contract = IERC20(erc20Address);
            erc20Contract.safeTransfer(to, agreementBalance);
        } else {
            (bool success, ) = payable(to).call{value: agreementBalance}("");   
            if (!success) {
                revert Agreements_EthTransferError();
            }
        }
    }
}
