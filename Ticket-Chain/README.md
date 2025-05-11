# Event Ticketing Smart Contract

A secure and feature-rich smart contract for managing event tickets on the Stacks blockchain using Clarity.

## Overview

This smart contract enables organizers to create and manage events, sell tickets, and provides attendees with the ability to purchase, transfer, and resell tickets in a secure and controlled environment. It leverages the Stacks blockchain to ensure transparency, prevent fraud, and eliminate counterfeit tickets.

## Features

### Event Management
- **Create Events**: Organizers can create events with customizable parameters including name, description, venue, date, ticket price, and maximum capacity.
- **Update Events**: Modify event details such as name, venue, date, and more.
- **Control Resale**: Set whether tickets can be resold and cap the maximum resale price.
- **Cancel Events**: Option to cancel events before they take place.

### Ticket Operations
- **Primary Sales**: Sell tickets directly to attendees.
- **Secondary Market**: Allow peer-to-peer resale of tickets within predefined price limits.
- **Ticket Transfers**: Enable gifting tickets to others without payment.
- **Validation & Check-in**: Secure validation mechanism for ticket redemption at events.

### Security Features
- **Role-based Access**: Distinct permissions for organizers and ticket holders.
- **Cryptographic Validation**: Secure validation codes to prevent ticket fraud.
- **Expiration Enforcement**: Automatic verification of event dates to prevent expired ticket operations.
- **Anti-Scalping Measures**: Configurable resale price caps to prevent excessive markups.

## Getting Started

### Prerequisites
- Stacks blockchain account
- [Clarinet](https://github.com/hirosystems/clarinet) for local development and testing
- Basic understanding of Clarity smart contracts

### Deployment

1. Clone the repository:
   ```bash
   git clone
   ```

2. Test the contract locally:
   ```bash
   clarinet test
   ```

3. Deploy to the Stacks blockchain:
   ```bash
   # Using Clarinet
   clarinet deploy --network=mainnet
   
   # Or using the Stacks CLI
   stacks deploy --network=mainnet Venue-Tickets.clar
   ```

## Contract Functions

### For Event Organizers

#### `create-event`
```clarity
(define-public (create-event 
  (name (string-ascii 100))
  (description (string-utf8 500))
  (venue (string-ascii 100))
  (date uint)
  (ticket-price uint)
  (total-tickets uint)
  (allow-resale bool)
  (max-resale-price uint)
))
```
Creates a new event with the specified parameters.

#### `update-event`
```clarity
(define-public (update-event
  (event-id uint)
  (name (string-ascii 100))
  (description (string-utf8 500))
  (venue (string-ascii 100))
  (date uint)
  (is-active bool)
  (allow-resale bool)
  (max-resale-price uint)
))
```
Updates an existing event's details.

#### `cancel-event`
```clarity
(define-public (cancel-event (event-id uint)))
```
Marks an event as canceled, preventing further ticket sales.

#### `redeem-ticket`
```clarity
(define-public (redeem-ticket (event-id uint) (ticket-id uint) (validation-code (buff 32))))
```
Validates and redeems a ticket using its unique validation code.

#### `check-in-attendee`
```clarity
(define-public (check-in-attendee (event-id uint) (ticket-id uint)))
```
Marks a ticket as checked in at the event venue.

### For Ticket Buyers/Holders

#### `buy-tickets`
```clarity
(define-public (buy-tickets (event-id uint) (quantity uint)))
```
Purchases one or more tickets for an event directly from the organizer.

#### `list-ticket-for-sale`
```clarity
(define-public (list-ticket-for-sale (event-id uint) (ticket-id uint) (price uint)))
```
Lists a ticket for resale on the secondary market.

#### `cancel-ticket-listing`
```clarity
(define-public (cancel-ticket-listing (event-id uint) (ticket-id uint)))
```
Removes a ticket from the secondary market.

#### `buy-ticket-secondary`
```clarity
(define-public (buy-ticket-secondary (event-id uint) (ticket-id uint)))
```
Purchases a ticket from another user on the secondary market.

#### `transfer-ticket`
```clarity
(define-public (transfer-ticket (event-id uint) (ticket-id uint) (recipient principal)))
```
Transfers ticket ownership to another user without payment.

### Read-Only Functions

#### `get-event-details`
```clarity
(define-read-only (get-event-details (event-id uint)))
```
Retrieves complete information about an event.

#### `get-ticket-details`
```clarity
(define-read-only (get-ticket-details (event-id uint) (ticket-id uint)))
```
Retrieves information about a specific ticket.

#### `get-user-tickets`
```clarity
(define-read-only (get-user-tickets (owner principal) (event-id uint)))
```
Lists all tickets owned by a user for a specific event.

#### `is-ticket-valid`
```clarity
(define-read-only (is-ticket-valid (event-id uint) (ticket-id uint) (owner principal)))
```
Checks if a ticket is valid (not redeemed and owned by the specified user).

#### `get-organizer-events`
```clarity
(define-read-only (get-organizer-events (organizer principal)))
```
Lists all events created by a specific organizer.

## Error Codes

| Code | Description |
|------|-------------|
| `ERR-NOT-AUTHORIZED` (u100) | Operation attempted by an unauthorized principal |
| `ERR-EVENT-NOT-FOUND` (u101) | Referenced event does not exist |
| `ERR-TICKET-NOT-FOUND` (u102) | Referenced ticket does not exist |
| `ERR-EVENT-EXPIRED` (u103) | Operation attempted on an expired event |
| `ERR-INSUFFICIENT-FUNDS` (u104) | Buyer has insufficient funds |
| `ERR-TICKETS-SOLD-OUT` (u105) | No tickets remaining for purchase |
| `ERR-ALREADY-REDEEMED` (u106) | Ticket has already been redeemed |
| `ERR-EVENT-ALREADY-EXISTS` (u107) | Event ID already in use |
| `ERR-INVALID-PRICE` (u108) | Ticket price exceeds allowed maximum |
| `ERR-INVALID-DATE` (u109) | Event date is in the past |
| `ERR-INVALID-TICKETS` (u110) | Invalid ticket quantity |
| `ERR-NOT-FOR-SALE` (u111) | Ticket is not available for purchase |
| `ERR-SELF-TRANSFER` (u112) | Attempted transfer to self |
| `ERR-ALREADY-CHECKED-IN` (u113) | Ticket has already been checked in |

## Data Structures

### Events Map
Stores all event details indexed by event ID.

### Tickets Map
Stores individual ticket information indexed by event ID and ticket ID.

### Event Counter Map
Tracks the number of events created by each organizer.

### Ticket Ownership Map
Maps users to their ticket holdings for each event.

### Ticket Validation Codes Map
Stores secure validation codes for ticket verification.

## Security Considerations

1. **Validation**: All inputs are validated before processing transactions.
2. **Authorization**: Functions verify caller has appropriate permissions.
3. **Secure Transfers**: Ticket transfers require ownership verification.
4. **Expiration Checks**: Operations on expired events are prevented.
5. **Anti-Fraud**: Validation codes ensure tickets can't be duplicated.

## Best Practices

1. **For Organizers**:
   - Set reasonable resale caps to prevent scalping
   - Consider event capacity carefully before creation
   - Test the validation process before the event

2. **For Ticket Holders**:
   - Store your validation codes securely
   - Verify event details before purchasing tickets
   - Ensure you have sufficient funds when making purchases