;; License Smart Contract
;; This contract allows for the creation, transfer, and management of digital licenses

(define-data-var contract-owner principal tx-sender)
(define-data-var license-counter uint u0)
(define-data-var contract-paused bool false)

;; License data structure
(define-map licenses
  uint
  {
    owner: principal,
    created-at: uint,
    expires-at: uint,
    transferable: bool,
    active: bool,
    metadata-url: (string-ascii 256)
  }
)

;; License ownership tracking
(define-map license-owners 
  principal 
  (list 20 uint)
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-LICENSE-NOT-FOUND u101)
(define-constant ERR-LICENSE-EXPIRED u102)
(define-constant ERR-LICENSE-NOT-TRANSFERABLE u103)
(define-constant ERR-CONTRACT-PAUSED u104)
(define-constant ERR-ALREADY-OWNER u105)
(define-constant ERR-INVALID-DURATION u106)

;; Read-only functions

(define-read-only (get-license-by-id (license-id uint))
  (map-get? licenses license-id)
)

(define-read-only (get-owner-licenses (owner principal))
  (default-to (list) (map-get? license-owners owner))
)

(define-read-only (is-license-active (license-id uint))
  (match (map-get? licenses license-id)
    license (and 
              (get active license) 
              (< (get-block-info? time u0) (get expires-at license))
            )
    false
  )
)

(define-read-only (get-license-count)
  (var-get license-counter)
)

(define-read-only (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Public functions

;; Create a new license
(define-public (create-license 
                (recipient principal) 
                (duration uint) 
                (transferable bool)
                (metadata-url (string-ascii 256)))
  (begin
    (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (asserts! (> duration u0) (err ERR-INVALID-DURATION))
    
    (let ((license-id (+ (var-get license-counter) u1))
          (current-time (unwrap-panic (get-block-info? time u0)))
          (expiration-time (+ (unwrap-panic (get-block-info? time u0)) duration)))
      
      ;; Update license counter
      (var-set license-counter license-id)
      
      ;; Create the license
      (map-set licenses license-id
        {
          owner: recipient,
          created-at: current-time,
          expires-at: expiration-time,
          transferable: transferable,
          active: true,
          metadata-url: metadata-url
        }
      )
      
      ;; Update owner's license list
      (map-set license-owners recipient 
        (append (default-to (list) (map-get? license-owners recipient)) license-id)
      )
      
      (ok license-id)
    )
  )
)

;; Transfer a license to a new owner
(define-public (transfer-license (license-id uint) (recipient principal))
  (let ((license (unwrap! (map-get? licenses license-id) (err ERR-LICENSE-NOT-FOUND))))
    (begin
      (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
      (asserts! (is-eq tx-sender (get owner license)) (err ERR-NOT-AUTHORIZED))
      (asserts! (get transferable license) (err ERR-LICENSE-NOT-TRANSFERABLE))
      (asserts! (get active license) (err ERR-LICENSE-NOT-FOUND))
      (asserts! (< (unwrap-panic (get-block-info? time u0)) (get expires-at license)) (err ERR-LICENSE-EXPIRED))
      (asserts! (not (is-eq tx-sender recipient)) (err ERR-ALREADY-OWNER))
      
      ;; Remove license from current owner's list
      (let ((current-owner-licenses (default-to (list) (map-get? license-owners tx-sender))))
        (map-set license-owners tx-sender 
          (filter filter-license-id current-owner-licenses)
        )
      )
      
      ;; Add license to new owner's list
      (map-set license-owners recipient 
        (append (default-to (list) (map-get? license-owners recipient)) license-id)
      )
      
      ;; Update license ownership
      (map-set licenses license-id
        (merge license { owner: recipient })
      )
      
      (ok true)
    )
  )
)

;; Helper function for filtering out a license ID
(define-private (filter-license-id (id uint))
  (not (is-eq id license-id))
)

;; Renew a license
(define-public (renew-license (license-id uint) (additional-duration uint))
  (let ((license (unwrap! (map-get? licenses license-id) (err ERR-LICENSE-NOT-FOUND))))
    (begin
      (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
      (asserts! (or (is-contract-owner) (is-eq tx-sender (get owner license))) (err ERR-NOT-AUTHORIZED))
      (asserts! (> additional-duration u0) (err ERR-INVALID-DURATION))
      
      ;; Update license expiration
      (map-set licenses license-id
        (merge license 
          { 
            expires-at: (+ (get expires-at license) additional-duration),
            active: true
          }
        )
      )
      
      (ok true)
    )
  )
)

;; Revoke a license
(define-public (revoke-license (license-id uint))
  (let ((license (unwrap! (map-get? licenses license-id) (err ERR-LICENSE-NOT-FOUND))))
    (begin
      (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
      (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
      
      ;; Deactivate the license
      (map-set licenses license-id
        (merge license { active: false })
      )
      
      (ok true)
    )
  )
)

;; Admin functions

;; Transfer contract ownership
(define-public (transfer-contract-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Pause/unpause the contract
(define-public (set-contract-pause (paused bool))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (var-set contract-paused paused)
    (ok true)
  )
)