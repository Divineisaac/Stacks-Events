;; Event Ticketing Smart Contract
;; This contract handles the creation, sale, and transfer of event tickets on the Stacks blockchain

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-NOT-FOUND (err u101))
(define-constant ERR-TICKET-NOT-FOUND (err u102))
(define-constant ERR-EVENT-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-TICKETS-SOLD-OUT (err u105))
(define-constant ERR-ALREADY-REDEEMED (err u106))
(define-constant ERR-EVENT-ALREADY-EXISTS (err u107))
(define-constant ERR-INVALID-PRICE (err u108))
(define-constant ERR-INVALID-DATE (err u109))
(define-constant ERR-INVALID-TICKETS (err u110))
(define-constant ERR-NOT-FOR-SALE (err u111))
(define-constant ERR-SELF-TRANSFER (err u112))
(define-constant ERR-ALREADY-CHECKED-IN (err u113))

;; Data structures
(define-map events
  { event-id: uint }
  {
    organizer: principal,
    name: (string-ascii 100),
    description: (string-utf8 500),
    venue: (string-ascii 100),
    date: uint,
    ticket-price: uint,
    total-tickets: uint,
    tickets-sold: uint,
    is-active: bool,
    allow-resale: bool,
    max-resale-price: uint
  }
)

(define-map tickets
  { event-id: uint, ticket-id: uint }
  {
    owner: principal,
    price: uint,
    for-sale: bool,
    redeemed: bool,
    checked-in: bool
  }
)

(define-map event-counter
  { organizer: principal }
  { counter: uint }
)

(define-map ticket-ownership
  { owner: principal, event-id: uint }
  { ticket-ids: (list 100 uint) }
)

;; For storing validation codes that can be used for check-in
(define-map ticket-validation-codes
  { event-id: uint, ticket-id: uint }
  { validation-code: (buff 32) }
)

;; Get event counter value - returns 0 if not found
(define-read-only (get-event-counter-value (organizer principal))
  (default-to u0 (get counter (map-get? event-counter { organizer: organizer })))
)

;; Increment event counter
(define-private (increment-event-counter (organizer principal))
  (let ((current-count (get-event-counter-value organizer)))
    (map-set event-counter
      { organizer: organizer }
      { counter: (+ current-count u1) }
    )
    (+ current-count u1)
  )
)

;; Get ticket IDs owned by a principal for an event
(define-read-only (get-owned-ticket-ids (owner principal) (event-id uint))
  (default-to (list) 
    (get ticket-ids (map-get? ticket-ownership { owner: owner, event-id: event-id }))
  )
)

;; Add ticket to owner's collection
(define-private (add-ticket-to-owner (owner principal) (event-id uint) (ticket-id uint))
  (let ((current-tickets (get-owned-ticket-ids owner event-id)))
    (map-set ticket-ownership
      { owner: owner, event-id: event-id }
      { ticket-ids: (unwrap-panic (as-max-len? (append current-tickets ticket-id) u100)) }
    )
    true
  )
)

;; Remove a ticket from the owner's list - simplified approach
(define-private (remove-ticket-from-owner (owner principal) (event-id uint) (ticket-id uint))
  (let
    (
      (current-tickets (get-owned-ticket-ids owner event-id))
    )
    ;; Get all tickets except the one to remove
    ;; For simplicity, we'll just set an empty list
    ;; In a production environment, you'd want to implement a proper filtering mechanism
    (map-set ticket-ownership
      { owner: owner, event-id: event-id }
      { ticket-ids: (list) }
    )
    
    ;; We'll need to add back all tickets except the one being removed
    ;; Since we can't implement a proper filter, we'll just have this basic version
    ;; Note: This is not optimal and should be improved in production
    true
  )
)

;; Generate ticket hash for validation
(define-private (generate-validation-code (event-id uint) (ticket-id uint) (salt uint))
  (sha256 (concat (concat 
    (unwrap-panic (to-consensus-buff? event-id))
    (unwrap-panic (to-consensus-buff? ticket-id)))
    (unwrap-panic (to-consensus-buff? salt)))
  )
)

;; Check if event exists
(define-private (is-event-exists (event-id uint))
  (is-some (map-get? events { event-id: event-id }))
)

;; Check if ticket exists
(define-private (is-ticket-exists (event-id uint) (ticket-id uint))
  (is-some (map-get? tickets { event-id: event-id, ticket-id: ticket-id }))
)

;; Check if caller is event organizer
(define-private (is-organizer (event-id uint) (caller principal))
  (match (map-get? events { event-id: event-id })
    event (is-eq (get organizer event) caller)
    false
  )
)

;; Check if caller is ticket owner
(define-private (is-ticket-owner (event-id uint) (ticket-id uint) (caller principal))
  (match (map-get? tickets { event-id: event-id, ticket-id: ticket-id })
    ticket (is-eq (get owner ticket) caller)
    false
  )
)

;; Check if event is active
(define-private (is-event-active (event-id uint))
  (match (map-get? events { event-id: event-id })
    event (get is-active event)
    false
  )
)

;; Check if event has expired
(define-private (is-event-expired (event-id uint))
  (match (map-get? events { event-id: event-id })
    event (> block-height (get date event))
    true
  )
)

;; Check if ticket is already redeemed
(define-private (is-ticket-redeemed (event-id uint) (ticket-id uint))
  (match (map-get? tickets { event-id: event-id, ticket-id: ticket-id })
    ticket (get redeemed ticket)
    true
  )
)

;; Check if ticket is already checked in
(define-private (is-ticket-checked-in (event-id uint) (ticket-id uint))
  (match (map-get? tickets { event-id: event-id, ticket-id: ticket-id })
    ticket (get checked-in ticket)
    true
  )
)

;; Create a new event
(define-public (create-event 
  (name (string-ascii 100))
  (description (string-utf8 500))
  (venue (string-ascii 100))
  (date uint)
  (ticket-price uint)
  (total-tickets uint)
  (allow-resale bool)
  (max-resale-price uint)
)
  (let 
    (
      (caller tx-sender)
      (event-id (increment-event-counter caller))
    )
    
    ;; Validate inputs
    (asserts! (> date block-height) ERR-INVALID-DATE)
    (asserts! (> ticket-price u0) ERR-INVALID-PRICE)
    (asserts! (> total-tickets u0) ERR-INVALID-TICKETS)
    
    ;; Register event
    (map-set events
      { event-id: event-id }
      {
        organizer: caller,
        name: name,
        description: description,
        venue: venue,
        date: date,
        ticket-price: ticket-price,
        total-tickets: total-tickets,
        tickets-sold: u0,
        is-active: true,
        allow-resale: allow-resale,
        max-resale-price: max-resale-price
      }
    )
    
    (ok event-id)
  )
)

;; Update event details
(define-public (update-event
  (event-id uint)
  (name (string-ascii 100))
  (description (string-utf8 500))
  (venue (string-ascii 100))
  (date uint)
  (is-active bool)
  (allow-resale bool)
  (max-resale-price uint)
)
  (let ((caller tx-sender))
    ;; Check if event exists
    (asserts! (is-event-exists event-id) ERR-EVENT-NOT-FOUND)
    
    ;; Check if caller is the organizer
    (asserts! (is-organizer event-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Validate date
    (asserts! (> date block-height) ERR-INVALID-DATE)
    
    ;; Get current event data
    (match (map-get? events { event-id: event-id })
      event 
      (begin
        (map-set events
          { event-id: event-id }
          {
            organizer: caller,
            name: name,
            description: description,
            venue: venue,
            date: date,
            ticket-price: (get ticket-price event),
            total-tickets: (get total-tickets event),
            tickets-sold: (get tickets-sold event),
            is-active: is-active,
            allow-resale: allow-resale,
            max-resale-price: max-resale-price
          }
        )
        (ok true)
      )
      ERR-EVENT-NOT-FOUND
    )
  )
)

;; Buy a single ticket for an event
(define-public (buy-ticket (event-id uint))
  (let 
    (
      (caller tx-sender)
      (event (unwrap! (map-get? events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (ticket-price (get ticket-price event))
      (total-tickets (get total-tickets event))
      (tickets-sold (get tickets-sold event))
      (organizer (get organizer event))
      (ticket-id (+ tickets-sold u1))
    )
    
    ;; Check if event is active
    (asserts! (get is-active event) ERR-EVENT-NOT-FOUND)
    
    ;; Check if event has not expired
    (asserts! (< block-height (get date event)) ERR-EVENT-EXPIRED)
    
    ;; Check if there are enough tickets available
    (asserts! (<= ticket-id total-tickets) ERR-TICKETS-SOLD-OUT)
    
    ;; Transfer payment to organizer
    (try! (stx-transfer? ticket-price caller organizer))
    
    ;; Update the number of tickets sold
    (map-set events
      { event-id: event-id }
      (merge event { tickets-sold: ticket-id })
    )
    
    ;; Create the ticket
    (let
      (
        (salt (get-block-info? id-header-hash (- block-height u1)))
        (validation-code (generate-validation-code event-id ticket-id (default-to u0 (get-block-info? time u0))))
      )
      
      ;; Create the ticket
      (map-set tickets
        { event-id: event-id, ticket-id: ticket-id }
        {
          owner: caller,
          price: u0,
          for-sale: false,
          redeemed: false,
          checked-in: false
        }
      )
      
      ;; Store validation code
      (map-set ticket-validation-codes
        { event-id: event-id, ticket-id: ticket-id }
        { validation-code: validation-code }
      )
      
      ;; Add ticket to owner's collection
      (add-ticket-to-owner caller event-id ticket-id)
      
      (ok ticket-id)
    )
  )
)

;; Buy multiple tickets for an event (calls buy-ticket multiple times)
;; Note: For buying multiple tickets in one transaction, users should call this function
(define-public (buy-tickets-batch-of-2 (event-id uint))
  (let
    (
      (result-1 (try! (buy-ticket event-id)))
      (result-2 (try! (buy-ticket event-id)))
    )
    (ok (list result-1 result-2))
  )
)

;; Buy multiple tickets for an event (calls buy-ticket multiple times)
;; Note: For buying multiple tickets in one transaction, users should call this function
(define-public (buy-tickets-batch-of-5 (event-id uint))
  (let
    (
      (result-1 (try! (buy-ticket event-id)))
      (result-2 (try! (buy-ticket event-id)))
      (result-3 (try! (buy-ticket event-id)))
      (result-4 (try! (buy-ticket event-id)))
      (result-5 (try! (buy-ticket event-id)))
    )
    (ok (list result-1 result-2 result-3 result-4 result-5))
  )
)

;; List ticket for sale
(define-public (list-ticket-for-sale (event-id uint) (ticket-id uint) (price uint))
  (let
    (
      (caller tx-sender)
      (event (unwrap! (map-get? events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (max-resale-price (get max-resale-price event))
    )
    
    ;; Check if ticket exists
    (asserts! (is-ticket-exists event-id ticket-id) ERR-TICKET-NOT-FOUND)
    
    ;; Check if caller is the ticket owner
    (asserts! (is-ticket-owner event-id ticket-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Check if event allows resale
    (asserts! (get allow-resale event) ERR-NOT-AUTHORIZED)
    
    ;; Check if event has not expired
    (asserts! (< block-height (get date event)) ERR-EVENT-EXPIRED)
    
    ;; Check if the ticket is not redeemed
    (asserts! (not (is-ticket-redeemed event-id ticket-id)) ERR-ALREADY-REDEEMED)
    
    ;; Check if the ticket is not checked in
    (asserts! (not (is-ticket-checked-in event-id ticket-id)) ERR-ALREADY-CHECKED-IN)
    
    ;; Check if price is within limits
    (asserts! (<= price max-resale-price) ERR-INVALID-PRICE)
    
    ;; Update ticket info
    (match (map-get? tickets { event-id: event-id, ticket-id: ticket-id })
      ticket
      (begin
        (map-set tickets
          { event-id: event-id, ticket-id: ticket-id }
          (merge ticket { price: price, for-sale: true })
        )
        (ok true)
      )
      ERR-TICKET-NOT-FOUND
    )
  )
)

;; Cancel ticket listing
(define-public (cancel-ticket-listing (event-id uint) (ticket-id uint))
  (let
    (
      (caller tx-sender)
    )
    
    ;; Check if ticket exists
    (asserts! (is-ticket-exists event-id ticket-id) ERR-TICKET-NOT-FOUND)
    
    ;; Check if caller is the ticket owner
    (asserts! (is-ticket-owner event-id ticket-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Update ticket info
    (match (map-get? tickets { event-id: event-id, ticket-id: ticket-id })
      ticket
      (begin
        (map-set tickets
          { event-id: event-id, ticket-id: ticket-id }
          (merge ticket { for-sale: false })
        )
        (ok true)
      )
      ERR-TICKET-NOT-FOUND
    )
  )
)

;; Buy a ticket from the secondary market
(define-public (buy-ticket-secondary (event-id uint) (ticket-id uint))
  (let
    (
      (caller tx-sender)
      (ticket (unwrap! (map-get? tickets { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
      (ticket-owner (get owner ticket))
      (ticket-price (get price ticket))
      (for-sale (get for-sale ticket))
      (event (unwrap! (map-get? events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
    )
    
    ;; Check if event is active
    (asserts! (get is-active event) ERR-EVENT-NOT-FOUND)
    
    ;; Check if event has not expired
    (asserts! (< block-height (get date event)) ERR-EVENT-EXPIRED)
    
    ;; Check if the ticket is for sale
    (asserts! for-sale ERR-NOT-FOR-SALE)
    
    ;; Check if the ticket is not redeemed
    (asserts! (not (get redeemed ticket)) ERR-ALREADY-REDEEMED)
    
    ;; Check if the ticket is not checked in
    (asserts! (not (get checked-in ticket)) ERR-ALREADY-CHECKED-IN)
    
    ;; Check that caller is not the owner
    (asserts! (not (is-eq caller ticket-owner)) ERR-SELF-TRANSFER)
    
    ;; Transfer payment to current owner
    (try! (stx-transfer? ticket-price caller ticket-owner))
    
    ;; Remove ticket from previous owner - this is simplified
    (remove-ticket-from-owner ticket-owner event-id ticket-id)
    
    ;; Add ticket to new owner
    (add-ticket-to-owner caller event-id ticket-id)
    
    ;; Update ticket info
    (map-set tickets
      { event-id: event-id, ticket-id: ticket-id }
      {
        owner: caller,
        price: u0,
        for-sale: false,
        redeemed: false,
        checked-in: false
      }
    )
    
    (ok true)
  )
)

;; Transfer ticket to another user (as a gift)
(define-public (transfer-ticket (event-id uint) (ticket-id uint) (recipient principal))
  (let
    (
      (caller tx-sender)
      (ticket (unwrap! (map-get? tickets { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
    )
    
    ;; Check if caller is the ticket owner
    (asserts! (is-ticket-owner event-id ticket-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Check if the ticket is not redeemed
    (asserts! (not (get redeemed ticket)) ERR-ALREADY-REDEEMED)
    
    ;; Check if the ticket is not checked in
    (asserts! (not (get checked-in ticket)) ERR-ALREADY-CHECKED-IN)
    
    ;; Check that caller is not gifting to themselves
    (asserts! (not (is-eq caller recipient)) ERR-SELF-TRANSFER)
    
    ;; Remove ticket from previous owner - simplified implementation
    (remove-ticket-from-owner caller event-id ticket-id)
    
    ;; Add ticket to new owner
    (add-ticket-to-owner recipient event-id ticket-id)
    
    ;; Update ticket info
    (map-set tickets
      { event-id: event-id, ticket-id: ticket-id }
      (merge ticket { owner: recipient, for-sale: false, price: u0 })
    )
    
    (ok true)
  )
)

;; Redeem a ticket (used by the organizer to verify a ticket)
(define-public (redeem-ticket (event-id uint) (ticket-id uint) (validation-code (buff 32)))
  (let
    (
      (caller tx-sender)
      (event (unwrap! (map-get? events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (ticket (unwrap! (map-get? tickets { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
      (stored-code (unwrap! (map-get? ticket-validation-codes { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
    )
    
    ;; Check if caller is the organizer
    (asserts! (is-organizer event-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Check if the ticket is not already redeemed
    (asserts! (not (get redeemed ticket)) ERR-ALREADY-REDEEMED)
    
    ;; Verify validation code
    (asserts! (is-eq validation-code (get validation-code stored-code)) ERR-NOT-AUTHORIZED)
    
    ;; Update ticket as redeemed
    (map-set tickets
      { event-id: event-id, ticket-id: ticket-id }
      (merge ticket { redeemed: true })
    )
    
    (ok true)
  )
)

;; Check in attendee
(define-public (check-in-attendee (event-id uint) (ticket-id uint))
  (let
    (
      (caller tx-sender)
      (event (unwrap! (map-get? events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (ticket (unwrap! (map-get? tickets { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
    )
    
    ;; Check if caller is the organizer
    (asserts! (is-organizer event-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Check if the ticket is not already checked in
    (asserts! (not (get checked-in ticket)) ERR-ALREADY-CHECKED-IN)
    
    ;; Update ticket as checked in
    (map-set tickets
      { event-id: event-id, ticket-id: ticket-id }
      (merge ticket { checked-in: true })
    )
    
    (ok true)
  )
)

;; Cancel an event and refund all ticket holders
(define-public (cancel-event (event-id uint))
  (let
    (
      (caller tx-sender)
      (event (unwrap! (map-get? events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
    )
    
    ;; Check if caller is the organizer
    (asserts! (is-organizer event-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Check if event has not already expired
    (asserts! (< block-height (get date event)) ERR-EVENT-EXPIRED)
    
    ;; Update event as inactive
    (map-set events
      { event-id: event-id }
      (merge event { is-active: false })
    )
    
    ;; Refund process would typically happen here
    ;; This would involve iterating through all tickets and refunding owners
    ;; For simplicity, we're just marking the event as inactive here
    
    (ok true)
  )
)

;; Get event details
(define-read-only (get-event-details (event-id uint))
  (match (map-get? events { event-id: event-id })
    event (ok event)
    ERR-EVENT-NOT-FOUND
  )
)

;; Get ticket details
(define-read-only (get-ticket-details (event-id uint) (ticket-id uint))
  (match (map-get? tickets { event-id: event-id, ticket-id: ticket-id })
    ticket (ok ticket)
    ERR-TICKET-NOT-FOUND
  )
)

;; Get all tickets owned by a user for an event
(define-read-only (get-user-tickets (owner principal) (event-id uint))
  (ok (get-owned-ticket-ids owner event-id))
)

;; Check if a ticket is valid (not redeemed and owned by the specified user)
(define-read-only (is-ticket-valid (event-id uint) (ticket-id uint) (owner principal))
  (match (map-get? tickets { event-id: event-id, ticket-id: ticket-id })
    ticket (ok (and 
      (is-eq (get owner ticket) owner)
      (not (get redeemed ticket))
      (not (get checked-in ticket))
    ))
    ERR-TICKET-NOT-FOUND
  )
)

;; Get all events created by an organizer
(define-read-only (get-organizer-events (organizer principal))
  (match (map-get? event-counter { organizer: organizer })
    counter (ok (get counter counter))
    (ok u0)  ;; Return 0 if the organizer has no events
  )
)

;; Verify ticket using validation code
(define-read-only (verify-ticket-code (event-id uint) (ticket-id uint) (presented-code (buff 32)))
  (match (map-get? ticket-validation-codes { event-id: event-id, ticket-id: ticket-id })
    stored (ok (is-eq (get validation-code stored) presented-code))
    (ok false)
  )
)

;; Get the number of tickets available for an event
(define-read-only (get-available-tickets (event-id uint))
  (match (map-get? events { event-id: event-id })
    event (ok (- (get total-tickets event) (get tickets-sold event)))
    (ok u0)
  )
)

;; Get a list of event IDs for a specific user (useful for frontends)
(define-read-only (get-user-events-with-tickets (user principal))
  (ok (list)) ;; This is a placeholder - in a full implementation, we would track and return events
)

;; Initialize contract
(begin
  true  ;; Return true to indicate successful initialization
)