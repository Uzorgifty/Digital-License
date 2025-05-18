# Clarity License Contract

A smart contract for managing digital licenses on the Stacks blockchain.

## Overview

This smart contract provides a complete solution for creating, transferring, and managing digital licenses. It allows the contract owner to issue licenses to users with configurable parameters such as duration, transferability, and associated metadata.

## Features

- **License Creation**: Create new licenses with customizable parameters
- **License Transfer**: Transfer licenses between users (when allowed)
- **License Renewal**: Extend the validity period of existing licenses
- **License Revocation**: Revoke licenses when necessary
- **Ownership Tracking**: Track which licenses are owned by which users
- **Admin Controls**: Contract ownership management and pause functionality

## Contract Structure

The contract uses several data structures:

- `licenses`: Map storing license details indexed by license ID
- `license-owners`: Map tracking all licenses owned by each principal
- `contract-owner`: Variable storing the contract administrator
- `license-counter`: Variable tracking the total number of issued licenses
- `contract-paused`: Variable indicating if contract operations are paused

## Error Codes

| Code | Description |
|------|-------------|
| `ERR-NOT-AUTHORIZED` (u100) | User doesn't have permission for this operation |
| `ERR-LICENSE-NOT-FOUND` (u101) | The requested license doesn't exist |
| `ERR-LICENSE-EXPIRED` (u102) | The license has expired |
| `ERR-LICENSE-NOT-TRANSFERABLE` (u103) | The license can't be transferred |
| `ERR-CONTRACT-PAUSED` (u104) | Contract operations are currently paused |
| `ERR-ALREADY-OWNER` (u105) | The recipient already owns the license |
| `ERR-INVALID-DURATION` (u106) | The specified duration is invalid |

## Public Functions

### Read-Only Functions

- `get-license-by-id`: Retrieves license details by ID
- `get-owner-licenses`: Gets all licenses owned by a principal
- `is-license-active`: Checks if a license is active and not expired
- `get-license-count`: Returns the total number of licenses issued
- `is-contract-owner`: Checks if caller is the contract owner

### License Management Functions

- `create-license`: Creates a new license for a recipient
- `transfer-license`: Transfers a license to a new owner
- `renew-license`: Extends the validity period of a license
- `revoke-license`: Deactivates a license

### Administrative Functions

- `transfer-contract-ownership`: Transfers contract ownership to a new principal
- `set-contract-pause`: Pauses or unpauses contract operations

## Example Usage

### Creating a License

```clarity
;; Create a 1-year transferable license
(contract-call? .license-contract create-license 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; recipient
  (* 365 144)                                   ;; duration (blocks, ~1 year)
  true                                          ;; transferable
  "https://example.com/license/metadata"        ;; metadata URL
)
```

### Transferring a License

```clarity
;; Transfer license #1 to another user
(contract-call? .license-contract transfer-license 
  u1                                            ;; license ID
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG   ;; recipient
)
```

### Renewing a License

```clarity
;; Extend license #1 by 6 months
(contract-call? .license-contract renew-license 
  u1                                            ;; license ID
  (* 182 144)                                   ;; additional duration (blocks, ~6 months)
)
```

## License Data Structure

Each license contains the following information:

- `owner`: The principal who owns the license
- `created-at`: Block time when the license was created
- `expires-at`: Block time when the license expires
- `transferable`: Whether the license can be transferred to others
- `active`: Whether the license is currently active
- `metadata-url`: URL pointing to additional license metadata

## Development and Deployment

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) for local development and testing
- [Stacks Wallet](https://hiro.so/wallet) for contract deployment


## Security Considerations

- The contract owner has significant control over licenses (creation and revocation)
- License transfers are only possible if the license is marked as transferable
- Contract operations can be paused in case of emergencies

## Future Improvements

- Add tiered licensing models
- Implement fee collection for license creation and renewal
- Add bulk operations for license management
- Support for license terms and conditions
- Implement license approval workflows