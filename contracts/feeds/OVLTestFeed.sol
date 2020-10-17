// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

import "../../interfaces/overlay/IOVLFeed.sol";

contract OVLTestFeed is IOVLFeed {
  int256 public price;

  // WARNING: This is only for dummy testing
  function getData() public virtual override returns (int256, uint256) {
    return (price, 0);
  }

  function setData(int256 _price) public {
    price = _price;
  }

}
