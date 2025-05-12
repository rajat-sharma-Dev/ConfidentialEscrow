# 🔐 Encrypted Escrow Smart Contract

This project implements a **confidential escrow mechanism** on Ethereum using **Inco Network's Lightning SDK**, enabling secure and privacy-preserving transactions between a buyer and a seller.

## ✨ Overview

In traditional escrow systems, transaction details and access logic are publicly visible on-chain. This encrypted escrow solution introduces **privacy by design** — fund access is controlled using **encrypted keys**, making it virtually impossible for unauthorized entities to extract funds or reverse engineer access logic.

## 🧩 How It Works

- A **buyer** initiates the transaction by calling the main escrow contract.
- The escrow contract deploys a **dedicated vault contract** that holds the buyer's funds.
- The buyer generates an **encrypted key** using `e.rand()` (Inco SDK) and provides it during deposit.
- The vault locks the funds; the **seller** cannot access them without permission.
- Once satisfied, the buyer shares access using `e.allow()` to grant the seller permission.
- The seller uses the key handle to unlock and withdraw funds securely.

## 📦 Contracts

- `ConfidentialEscrow.sol`: Manages vault deployment and buyer/seller flow.
- `EncryptedVault.sol`: Securely holds the funds using Inco SDK encrypted primitives.

## 🛠️ Stack

- [Solidity](https://soliditylang.org/)
- [Foundry](https://book.getfoundry.sh/) — for local development, testing, and deployment
- [Inco Lightning SDK](https://docs.inco.network/lightning-sdk) — for encrypted variable handling and permissioning

## 🚀 Features

- 🔐 **On-chain confidentiality** using Inco's encrypted types like `euint256`
- ✅ **Fine-grained permission control** via `e.allow()` and `e.isAllowed()`
- 🧱 **Modular architecture** separating business logic from fund custody
- 🛡️ **Security-first design**, reducing attack surface and information leakage

## 📁 Usage

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/encrypted-escrow.git
   cd encrypted-escrow
