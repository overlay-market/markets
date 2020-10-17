// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.6.6;

// import "@uniswapV2/periphery/contracts/examples/ExampleOracleSimple.sol";
import "../../interfaces/overlay/IOVLFeed.sol";

contract OVLUniswapV2Feed is IOVLFeed {
  uint public period;

  // TODO: Implement!
  function getData() public view virtual override returns (int256, uint256) {
  }

}
