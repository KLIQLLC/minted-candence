import GGCoin from "../../contracts/GGCoin.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

// This script returns an account's GGCoin balance.

pub fun main(address: Address): UFix64 {
    let account = getAccount(address)
    
    let vaultRef = account.getCapability(GGCoin.BalancePublicPath)!.borrow<&GGCoin.Vault{FungibleToken.Balance}>()
        ?? panic("Could not borrow Balance reference to the Vault")

    return vaultRef.balance
}
