import pytest

from brownie import OVLToken, OVLFPosition, OVLTestFeed, accounts


@pytest.fixture
def deployment():
    gov = accounts[0]
    token = OVLToken.deploy("Overlay", "OVL", { 'from': gov })
    token.grantRole(token.MINTER_ROLE(), gov.address, { 'from': gov })
    token.mint(1000*1e18, {'from': gov})
    token.transfer(accounts[1], 1000*1e18, {'from': gov})

    feed = OVLTestFeed.deploy({'from': gov})
    feed.setData(375*1e8)

    pos = OVLFPosition.deploy("uri", token.address, feed.address, {
        'from': gov
    })
    token.grantRole(token.MINTER_ROLE(), pos.address, { 'from': gov })
    token.increaseAllowance(pos.address, 1000*1e18, {'from': accounts[1]})
    return token, feed, pos

def test_deployment(deployment):
    token, feed, pos = deployment
    gov = accounts[0]
    assert pos.governance() == gov.address
    assert pos.treasury() == gov.address
    assert pos.feed() == feed.address
    assert pos.token() == token.address

def test_build(deployment):
    token, feed, pos = deployment
    gov = accounts[0]
    acc = accounts[1]
    tx = pos.build(100*1e18, True, 1e18, {'from': acc})
    assert 'Build' in tx.events and tx.events['Build']['by'] == acc.address
    id = pos.getId(True, 1e18, 375*1e8)

    # Check pos attrs
    assert id == pos.open()[-1] == tx.events['Build']['id']
    assert pos.isLong(id) == True
    assert pos.leverageOf(id) == 1e18
    assert pos.lockPriceOf(id) == 375*1e8
    assert pos.liquidationPriceOf(id) == 0

    # Check balances and fees
    assert token.balanceOf(acc.address) == 900*1e18
    assert token.balanceOf(pos.address) == 100*1e18 * (1-0.0015) # extracted trade fees
    assert pos.balanceOf(acc.address, id) == pos.amountLockedIn(id) == tx.events['Build']['value'] == 100*1e18 * (1-0.0015)
    assert token.balanceOf(pos.treasury()) == (100*1e18 * 0.0015/2.0) # treasury gets half the fees, other half gets burned
    assert token.totalSupply() == (1000*1e18 - 100*1e18 * 0.0015/2.0)

    # Try building a long position with leverage
    tx_2 = pos.build(50*1e18, True, 5e18, {'from': acc})
    id_2 = pos.getId(True, 5e18, 375*1e8)
    assert id_2 == tx_2.events['Build']['id']
    assert pos.leverageOf(id_2) == 5e18
    assert pos.balanceOf(acc.address, id_2) == pos.amountLockedIn(id_2) == tx_2.events['Build']['value'] == 50*1e18 * (1 - 0.0015*5.0)
    assert pos.liquidationPriceOf(id_2) == 375*1e8 * (1 - 1/5.0) # liquidate = lockPrice * (1-1/leverage)

    # TODO: short position, 1x, 2.5x


def test_unwind(deployment):
    # TODO: build the positions first as above but without asserts ...
    pass

def test_liquidate(deployment):
    pass
