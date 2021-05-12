import FungibleToken from "./FungibleToken.cdc"

pub contract GGCoin: FungibleToken {
    
    // events
    pub event TokensInitialized(initialSupply: UFix64)
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensDeposited(amount: UFix64, to: Address?)
    pub event TokensMinted(amount: UFix64)
    pub event TokensBurned(amount: UFix64)
    pub event MinterCreated(allowedAmount: UFix64)


    // Named paths
    pub let VaultStoragePath: StoragePath
    pub let ReceiverPublicPath: PublicPath
    pub let BalancePublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    // Total supply of GGCoins in existence
    pub var totalSupply: UFix64

    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {

        pub var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @GGCoin.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            GGCoin.totalSupply = GGCoin.totalSupply - self.balance
            if(self.balance > 0.0) {
                emit TokensBurned(amount: self.balance)
            }
        }
    }

    pub fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
    }

    pub resource Administrator {
        pub fun createNewMinter(allowedAmount: UFix64): @Minter {
            emit MinterCreated(allowedAmount: allowedAmount)
            return <-create Minter(allowedAmount: allowedAmount)
        }
    }

    pub resource Minter {
        pub var allowedAmount: UFix64
        
        pub fun mintTokens(amount: UFix64): @GGCoin.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
                amount <= self.allowedAmount: "Amount minted must be less than the allowed amount"
            }
            GGCoin.totalSupply = GGCoin.totalSupply + amount
            self.allowedAmount = self.allowedAmount - amount
            emit TokensMinted(amount: amount)
            return <-create Vault(balance: amount)
        }

        init(allowedAmount: UFix64) {
            self.allowedAmount = allowedAmount
        }
    }

    init() {
        self.VaultStoragePath = /storage/GGVault001
        self.ReceiverPublicPath = /public/GGReceiver001
        self.BalancePublicPath = /public/GGBalance001
        self.AdminStoragePath = /storage/GGAdmin001

        // Initialize contract state.
        self.totalSupply = 0.0

        // Create the one true Admin object and deposit it into the conttract account.
        let admin <- create Administrator()
        self.account.save(<-admin, to: self.AdminStoragePath)

        // Emit an event that shows that the contract was initialized.
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
