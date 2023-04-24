// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract RoleManager is AccessControlEnumerable {
    /********************
     * Global Variables *
     ********************/

    bytes32 public constant WORKER_ROLE = keccak256("WORKER_ROLE");
    mapping(address => address) private _transitions;

    /**********
     * Events *
     **********/

    event TransferAdmin(address indexed oldAdmin, address indexed newAdmin);
    event FinishTransferAdmin(
        address indexed oldAdmin,
        address indexed newAdmin
    );
    event CancelTransferAdmin(
        address indexed oldAdmin,
        address indexed newAdmin
    );

    /**********
     * Errors *
     **********/

    error ErrGrantRoleToZeroAddress();
    error ErrTransferAdminToSelf();
    error ErrAlreadyHasAdminRole();
    error ErrForbidden();
    error ErrAlreadyInTransition();
    error ErrNotInTransition();

    /************
     * Modifier *
     ************/

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert ErrForbidden();
        }
        _;
    }

    modifier onlyWorker() {
        if (!hasRole(WORKER_ROLE, _msgSender())) {
            revert ErrForbidden();
        }
        _;
    }

    modifier inTransition(address oldAdmin) {
        if (_transitions[oldAdmin] == address(0)) {
            revert ErrNotInTransition();
        }
        _;
    }

    modifier notInTransition(address oldAdmin) {
        if (_transitions[oldAdmin] != address(0)) {
            revert ErrAlreadyInTransition();
        }
        _;
    }

    /***************
     * Constructor *
     ***************/

    constructor(address newAdmin, address newWorker) {
        // grant new admin
        if (newAdmin == address(0)) {
            revert ErrGrantRoleToZeroAddress();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);

        // grant new worker if needed
        if (newWorker != address(0)) {
            _grantRole(WORKER_ROLE, newWorker);
        }
    }

    /*****************************
     * External/Public Functions *
     *****************************/

    /**
     * @dev Create a admin role transfer request.
     * @notice This function can only be called by the admin.
     * @param newAdmin - the address that admin role is transfered to.
     */
    function transferAdmin(address newAdmin)
        external
        onlyAdmin
        notInTransition(_msgSender())
    {
        address oldAdmin = _msgSender();

        if (newAdmin == address(0)) {
            revert ErrGrantRoleToZeroAddress();
        }
        if (newAdmin == oldAdmin) {
            revert ErrTransferAdminToSelf();
        }

        _transitions[oldAdmin] = newAdmin;

        emit TransferAdmin(oldAdmin, newAdmin);
    }

    /**
     * @dev Finish the admin transition.
     * Grant new admin and revoke old admin depends on the transition record.
     *
     * @notice This function can only be called by the newAdmin defined in the transition record.
     * @param oldAdmin - the original Admin address.
     */
    function finishTransferAdmin(address oldAdmin)
        external
        inTransition(oldAdmin)
    {
        address sender = _msgSender();

        if (_transitions[oldAdmin] != sender) {
            revert ErrForbidden();
        }

        _transitions[oldAdmin] = address(0);
        _grantRole(DEFAULT_ADMIN_ROLE, sender);
        _revokeRole(DEFAULT_ADMIN_ROLE, oldAdmin);

        emit FinishTransferAdmin(oldAdmin, sender);
    }

    /**
     * @dev Cancel the admin transition.
     * @notice This function can only be called by the original admin.
     */
    function cancelTransferAdmin() external inTransition(_msgSender()) {
        address oldAdmin = _msgSender();
        address newAdmin = _transitions[oldAdmin];

        _transitions[oldAdmin] = address(0);

        emit CancelTransferAdmin(oldAdmin, newAdmin);
    }

    /**
     * @dev Get the new admin address in the transition record.
     * @param oldAdmin - the original admin address.
     * @return newAdmin - the new admin address.
     */
    function transition(address oldAdmin) external view returns (address) {
        return _transitions[oldAdmin];
    }
}
