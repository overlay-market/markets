// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/math/SignedSafeMath.sol";

library SignedMath {

  using SignedSafeMath as int256;

  function abs(int256 a) internal pure returns (int256) {
    return a >= 0 ? a : a.mult(-1.0);
  }

}
