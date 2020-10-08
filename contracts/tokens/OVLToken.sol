// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelinV3/contracts/token/ERC20/ERC20.sol";
import "@openzeppelinV3/contracts/access/AccessControl.sol";

import "../../interfaces/overlay/IOVLToken.sol";

contract OVLToken is ERC20, AccessControl, IOVLToken {

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  constructor(string memory name, string memory symbol) public ERC20(name, symbol) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender()); // governance
  }

  function mint(uint256 _amount) public virtual override {
      require(hasRole(MINTER_ROLE, _msgSender()), "OVLToken: must have minter role to mint");
      _mint(_msgSender(), _amount);
  }

  function burn(uint256 _amount) public virtual override {
      require(hasRole(MINTER_ROLE, _msgSender()), "OVLToken: must have minter role to burn");
      _burn(_msgSender(), _amount);
  }

}
