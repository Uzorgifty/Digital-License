;; License Smart Contract
;; This contract allows for the creation, transfer, and management of digital licenses

(define-data-var contract-owner principal tx-sender)
(define-data-var license-counter uint u0)
(define-data-var contract-paused bool false)
(define-data-var current-filter-id uint u0) ;; For filter function

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
(define-constant ERR-TOO-MANY-LICENSES u107)
(define-constant ERR-LICENSE-ALREADY-OWNED u108)
(define-constant ERR-INVALID-PRINCIPAL u109)
(define-constant ERR-INVALID-METADATA-URL u110)

;; Read-only functions

(define-read-only (get-license-by-id (license-id uint))
  (map-get? licenses license-id)
)

(define-read-only (get-owner-licenses (owner principal))
  (default-to (list) (map-get? license-owners owner))
)

(define-read-only (is-license-active (license-id uint))
  (match (map-get? licenses license-id)
    license (let ((current-time (default-to u0 (get-block-info? time u0))))
              (and 
                (get active license) 
                (< current-time (get expires-at license))
              ))
    false
  )
)

(define-read-only (get-license-count)
  (var-get license-counter)
)

(define-read-only (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Validation functions

(define-private (is-valid-principal (address principal))
  ;; Check if principal is non-empty and not the zero address
  (and 
    (not (is-eq address 'SP000000000000000000002Q6VF78)) ;; Don't allow zero address
    true ;; Additional validation can be added here
  )
)

(define-private (is-valid-metadata-url (url (string-ascii 256)))
  ;; Check if URL is not empty
  (> (len url) u0)
)

;; Helper to safely add a license to owner's list
(define-private (add-license-to-owner (owner principal) (license-id uint))
  (begin
    ;; Validate owner principal
    (asserts! (is-valid-principal owner) (err ERR-INVALID-PRINCIPAL))
    
    (let (
      (current-licenses (default-to (list) (map-get? license-owners owner)))
      (contains-license (is-some (index-of current-licenses license-id)))
    )
      (if contains-license
        (err ERR-LICENSE-ALREADY-OWNED)
        (if (>= (len current-licenses) u19) ;; Check if we already have 19 or more licenses
          (err ERR-TOO-MANY-LICENSES)
          (begin
            (map-set license-owners owner (unwrap! (as-max-len? (concat current-licenses (list license-id)) u20) (err ERR-TOO-MANY-LICENSES)))
            (ok true)
          )
        )
      )
    )
  )
)

;; Helper function for filtering out a specific license ID
(define-private (not-equal-to-filter-id (id uint))
  (not (is-eq id (var-get current-filter-id)))
)

;; Helper function to safely remove a license from owner's list
(define-private (remove-license-from-owner (owner principal) (license-id uint))
  (begin
    ;; Validate owner principal
    (asserts! (is-valid-principal owner) (err ERR-INVALID-PRINCIPAL))
    
    (let ((current-licenses (default-to (list) (map-get? license-owners owner))))
      ;; Set the filter ID for the filter function to use
      (var-set current-filter-id license-id)
      (map-set license-owners owner 
        (filter not-equal-to-filter-id current-licenses)
      )
    )
    (ok true)
  )
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
    (asserts! (is-valid-principal recipient) (err ERR-INVALID-PRINCIPAL))
    (asserts! (is-valid-metadata-url metadata-url) (err ERR-INVALID-METADATA-URL))
    
    (let ((license-id (+ (var-get license-counter) u1))
          (current-time (default-to u0 (get-block-info? time u0)))
          (expiration-time (+ (default-to u0 (get-block-info? time u0)) duration)))
      
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
      (let ((result (add-license-to-owner recipient license-id)))
        (match result
          success (ok license-id)  ;; Return the license ID on success
          error (begin
            ;; Rollback the license creation
            (map-delete licenses license-id)
            (var-set license-counter (- license-id u1))
            (err error)  ;; Return the error code from add-license-to-owner
          )
        )
      )
    )
  )
)

;; Transfer a license to a new owner
(define-public (transfer-license (license-id uint) (recipient principal))
  (begin
    ;; Validate the recipient
    (asserts! (is-valid-principal recipient) (err ERR-INVALID-PRINCIPAL))
    
    ;; Check if the license exists
    (let ((license-opt (map-get? licenses license-id)))
      (asserts! (is-some license-opt) (err ERR-LICENSE-NOT-FOUND))
      
      (let ((license (unwrap-panic license-opt)))
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        (asserts! (is-eq tx-sender (get owner license)) (err ERR-NOT-AUTHORIZED))
        (asserts! (get transferable license) (err ERR-LICENSE-NOT-TRANSFERABLE))
        (asserts! (get active license) (err ERR-LICENSE-NOT-FOUND))
        
        (let ((current-time (default-to u0 (get-block-info? time u0))))
          (asserts! (< current-time (get expires-at license)) (err ERR-LICENSE-EXPIRED))
        )
        
        (asserts! (not (is-eq tx-sender recipient)) (err ERR-ALREADY-OWNER))
        
        ;; Try to add license to recipient's list first
        (let ((add-result (add-license-to-owner recipient license-id)))
          (asserts! (is-ok add-result) (err (unwrap-err-panic add-result)))
          
          ;; Remove license from current owner's list
          (unwrap-panic (remove-license-from-owner tx-sender license-id))
          
          ;; Update license ownership
          (map-set licenses license-id
            (merge license { owner: recipient })
          )
          
          (ok true)
        )
      )
    )
  )
)

;; Renew a license
(define-public (renew-license (license-id uint) (additional-duration uint))
  (begin
    (asserts! (> additional-duration u0) (err ERR-INVALID-DURATION))
    
    (let ((license-opt (map-get? licenses license-id)))
      (asserts! (is-some license-opt) (err ERR-LICENSE-NOT-FOUND))
      
      (let ((license (unwrap-panic license-opt)))
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        (asserts! (or (is-contract-owner) (is-eq tx-sender (get owner license))) (err ERR-NOT-AUTHORIZED))
        
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
)

;; Revoke a license
(define-public (revoke-license (license-id uint))
  (begin
    (let ((license-opt (map-get? licenses license-id)))
      (asserts! (is-some license-opt) (err ERR-LICENSE-NOT-FOUND))
      
      (let ((license (unwrap-panic license-opt)))
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
)

;; Admin functions

;; Transfer contract ownership
(define-public (transfer-contract-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-valid-principal new-owner) (err ERR-INVALID-PRINCIPAL))
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