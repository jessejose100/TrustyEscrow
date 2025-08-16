;; Decentralized Escrow Service for Freelance Work
;; This contract facilitates secure payments between clients and freelancers
;; by holding funds in escrow until work completion and approval

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-EXPIRED (err u107))

;; Status constants for escrow states
(define-constant STATUS-CREATED u0)
(define-constant STATUS-FUNDED u1)
(define-constant STATUS-WORK-SUBMITTED u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-DISPUTED u4)
(define-constant STATUS-CANCELLED u5)

;; data maps and vars
;; Main escrow data structure
(define-map escrows
  { escrow-id: uint }
  {
    client: principal,
    freelancer: principal,
    amount: uint,
    deadline: uint,
    status: uint,
    work-description: (string-ascii 500),
    created-at: uint
  }
)

;; Track dispute information
(define-map disputes
  { escrow-id: uint }
  {
    initiated-by: principal,
    reason: (string-ascii 300),
    resolution: (string-ascii 300),
    resolved: bool
  }
)

;; Global variables
(define-data-var next-escrow-id uint u1)
(define-data-var contract-fee-percentage uint u250) ;; 2.5% fee
(define-data-var total-fees-collected uint u0)

;; private functions
;; Calculate contract fee (2.5% of escrow amount)
(define-private (calculate-fee (amount uint))
  (/ (* amount (var-get contract-fee-percentage)) u10000)
)

;; Validate escrow exists and return escrow data
(define-private (get-escrow-or-fail (escrow-id uint))
  (match (map-get? escrows { escrow-id: escrow-id })
    escrow-data (ok escrow-data)
    ERR-NOT-FOUND
  )
)

;; Check if caller is authorized for escrow (client or freelancer)
(define-private (is-escrow-participant (escrow-id uint) (caller principal))
  (match (map-get? escrows { escrow-id: escrow-id })
    escrow-data (or (is-eq caller (get client escrow-data))
                   (is-eq caller (get freelancer escrow-data)))
    false
  )
)

;; public functions
;; Create new escrow contract
(define-public (create-escrow (freelancer principal) 
                             (amount uint) 
                             (deadline uint) 
                             (work-description (string-ascii 500)))
  (let ((escrow-id (var-get next-escrow-id)))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> deadline block-height) ERR-EXPIRED)
    (asserts! (is-none (map-get? escrows { escrow-id: escrow-id })) ERR-ALREADY-EXISTS)
    
    (map-set escrows
      { escrow-id: escrow-id }
      {
        client: tx-sender,
        freelancer: freelancer,
        amount: amount,
        deadline: deadline,
        status: STATUS-CREATED,
        work-description: work-description,
        created-at: block-height
      }
    )
    
    (var-set next-escrow-id (+ escrow-id u1))
    (print { event: "escrow-created", escrow-id: escrow-id, client: tx-sender, freelancer: freelancer, amount: amount })
    (ok escrow-id)
  )
)

;; Fund the escrow contract
(define-public (fund-escrow (escrow-id uint))
  (let ((escrow-data (try! (get-escrow-or-fail escrow-id))))
    (asserts! (is-eq tx-sender (get client escrow-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow-data) STATUS-CREATED) ERR-INVALID-STATUS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? (get amount escrow-data) tx-sender (as-contract tx-sender)))
    
    ;; Update status to funded
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { status: STATUS-FUNDED })
    )
    
    (print { event: "escrow-funded", escrow-id: escrow-id, amount: (get amount escrow-data) })
    (ok true)
  )
)

;; Submit work completion (called by freelancer)
(define-public (submit-work (escrow-id uint))
  (let ((escrow-data (try! (get-escrow-or-fail escrow-id))))
    (asserts! (is-eq tx-sender (get freelancer escrow-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow-data) STATUS-FUNDED) ERR-INVALID-STATUS)
    (asserts! (<= block-height (get deadline escrow-data)) ERR-EXPIRED)
    
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { status: STATUS-WORK-SUBMITTED })
    )
    
    (print { event: "work-submitted", escrow-id: escrow-id, freelancer: tx-sender })
    (ok true)
  )
)

;; Release funds to freelancer (called by client)
(define-public (approve-and-release (escrow-id uint))
  (let ((escrow-data (try! (get-escrow-or-fail escrow-id)))
        (fee (calculate-fee (get amount escrow-data)))
        (freelancer-payment (- (get amount escrow-data) fee)))
    
    (asserts! (is-eq tx-sender (get client escrow-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status escrow-data) STATUS-WORK-SUBMITTED) ERR-INVALID-STATUS)
    
    ;; Transfer payment to freelancer
    (try! (as-contract (stx-transfer? freelancer-payment tx-sender (get freelancer escrow-data))))
    
    ;; Collect fee
    (try! (as-contract (stx-transfer? fee tx-sender CONTRACT-OWNER)))
    (var-set total-fees-collected (+ (var-get total-fees-collected) fee))
    
    ;; Update status to completed
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { status: STATUS-COMPLETED })
    )
    
    (print { event: "payment-released", escrow-id: escrow-id, amount: freelancer-payment, fee: fee })
    (ok true)
  )
)

;; Initiate dispute (can be called by client or freelancer)
(define-public (initiate-dispute (escrow-id uint) (reason (string-ascii 300)))
  (let ((escrow-data (try! (get-escrow-or-fail escrow-id))))
    (asserts! (is-escrow-participant escrow-id tx-sender) ERR-UNAUTHORIZED)
    (asserts! (or (is-eq (get status escrow-data) STATUS-FUNDED)
                 (is-eq (get status escrow-data) STATUS-WORK-SUBMITTED)) ERR-INVALID-STATUS)
    
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { status: STATUS-DISPUTED })
    )
    
    (map-set disputes
      { escrow-id: escrow-id }
      {
        initiated-by: tx-sender,
        reason: reason,
        resolution: "",
        resolved: false
      }
    )
    
    (print { event: "dispute-initiated", escrow-id: escrow-id, initiated-by: tx-sender })
    (ok true)
  )
)

;; Complex dispute resolution function with multiple outcomes
;; This function allows the contract owner to resolve disputes with various options
(define-public (resolve-dispute-with-distribution (escrow-id uint) 
                                                  (resolution (string-ascii 300))
                                                  (client-percentage uint)
                                                  (freelancer-percentage uint)
                                                  (penalty-amount uint))
  (let ((escrow-data (try! (get-escrow-or-fail escrow-id)))
        (dispute-data (unwrap! (map-get? disputes { escrow-id: escrow-id }) ERR-NOT-FOUND))
        (total-amount (get amount escrow-data))
        (fee (calculate-fee total-amount))
        (distributable-amount (- total-amount fee penalty-amount))
        (client-share (/ (* distributable-amount client-percentage) u100))
        (freelancer-share (/ (* distributable-amount freelancer-percentage) u100)))
    
    ;; Authorization and validation checks
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-eq (get status escrow-data) STATUS-DISPUTED) ERR-INVALID-STATUS)
    (asserts! (is-eq (get resolved dispute-data) false) ERR-INVALID-STATUS)
    (asserts! (is-eq (+ client-percentage freelancer-percentage) u100) ERR-INVALID-AMOUNT)
    (asserts! (<= penalty-amount total-amount) ERR-INVALID-AMOUNT)
    
    ;; Distribute funds based on resolution percentages
    (if (> client-share u0)
        (try! (as-contract (stx-transfer? client-share tx-sender (get client escrow-data))))
        true)
    
    (if (> freelancer-share u0)
        (try! (as-contract (stx-transfer? freelancer-share tx-sender (get freelancer escrow-data))))
        true)
    
    ;; Collect standard fee plus any penalty
    (let ((total-fee-and-penalty (+ fee penalty-amount)))
      (if (> total-fee-and-penalty u0)
          (try! (as-contract (stx-transfer? total-fee-and-penalty tx-sender CONTRACT-OWNER)))
          true))
    
    ;; Update fees collected
    (var-set total-fees-collected (+ (var-get total-fees-collected) fee))
    
    ;; Mark dispute as resolved
    (map-set disputes
      { escrow-id: escrow-id }
      (merge dispute-data { 
        resolution: resolution, 
        resolved: true 
      }))
    
    ;; Update escrow status to completed
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow-data { status: STATUS-COMPLETED }))
    
    ;; Emit detailed resolution event
    (print { 
      event: "dispute-resolved", 
      escrow-id: escrow-id, 
      client-share: client-share,
      freelancer-share: freelancer-share,
      penalty: penalty-amount,
      resolution: resolution 
    })
    
    (ok {
      client-received: client-share,
      freelancer-received: freelancer-share,
      penalty-applied: penalty-amount,
      total-distributed: (+ client-share freelancer-share)
    })
  )
)


