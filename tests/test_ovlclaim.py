import pytest

from brownie import OVLToken, OVLClaim, accounts, exceptions


@pytest.fixture
def deployment():
    gov = accounts[0]
    token = OVLToken.deploy("Overlay", "OVL", { 'from': gov })
    token.grantRole(token.MINTER_ROLE(), gov.address, { 'from': gov })
    token.mint(100000*1e18, {'from': gov})
    claim = OVLClaim.deploy(token.address, 100*1e18, {'from': gov})
    token.transfer(claim.address, 200*1e18, {'from': gov})
    return token, claim

def test_withdraw(deployment):
    token, claim = deployment
    assert token.balanceOf(claim.address) == 200*1e18
    assert claim.token() == token.address

    tx = claim.withdraw({'from': accounts[1]})
    assert token.balanceOf(accounts[1]) == claim.amount() == 100*1e18
    assert token.balanceOf(claim.address) == 100*1e18
    assert 'Withdraw' in tx.events and tx.events['Withdraw']['by'] == accounts[1] and tx.events['Withdraw']['value'] == claim.amount()

    with pytest.raises(exceptions.VirtualMachineError):
        tx_rev = claim.withdraw({'from': accounts[1]})
        assert tx_rev.revert_msg == "OVLClaim: must not have already withdrawn"

    claim.withdraw({'from': accounts[2]})

    with pytest.raises(exceptions.VirtualMachineError):
        tx_rev_2 = claim.withdraw({'from': accounts[3]})
        assert tx_rev.revert_msg == "OVLClaim: no more funds to withdraw"
