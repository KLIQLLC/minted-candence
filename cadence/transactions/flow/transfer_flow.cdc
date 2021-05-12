import FungibleToken from "../../contracts/FungibleToken.cdc"



transaction(amount: UFix64, to: Address) {
    let vault: @FungibleToken.Vault
    prepare(signer: AuthAccount) {
        self.vault <- signer
          .borrow<&{FungibleToken.Provider}>(from: /storage/flowTokenVault)!
          .withdraw(amount: amount)
    }
    
    execute {
        getAccount(to)
          .getCapability(/public/flowTokenReceiver)!
          .borrow<&{FungibleToken.Receiver}>()!
          .deposit(from: <-self.vault)
    }
}