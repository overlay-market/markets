// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;


contract OVLFeedMock {
  int256 public price;

  // WARNING: This is only for dummy testing
  function data() external view returns (int256, uint256) {
    return (price, 0);
  }

  function fetchData() public returns (int256, uint256) {
    return (price, 0);
  }

  function setData(int256 _price) public {
    price = _price;
  }

}
