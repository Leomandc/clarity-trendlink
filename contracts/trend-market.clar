;; TrendLink Market Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant min-stake u100)
(define-constant max-duration u5256000) ;; ~2 months in blocks
(define-constant resolution-threshold u10) ;; 10% of total stake needed to resolve

;; Error codes
(define-constant err-owner-only (err u100))
(define-constant err-invalid-stake (err u101))
(define-constant err-market-exists (err u102))
(define-constant err-market-expired (err u103))
(define-constant err-invalid-duration (err u104))
(define-constant err-market-not-found (err u105))
(define-constant err-already-predicted (err u106))
(define-constant err-not-resolved (err u107))
(define-constant err-already-claimed (err u108))

;; Data structures
(define-map markets
  { market-id: uint }
  {
    creator: principal,
    description: (string-utf8 256),
    expiration: uint,
    total-stake: uint,
    resolved: bool,
    outcome: bool
  }
)

(define-map predictions
  { market-id: uint, user: principal }
  {
    prediction: bool,
    stake-amount: uint,
    claimed: bool
  }
)

;; Variables
(define-data-var market-nonce uint u0)
(define-data-var contract-paused bool false)

;; Events
(define-public (market-created-event (market-id uint) (creator principal) (description (string-utf8 256)))
  (ok true))

(define-public (prediction-made-event (market-id uint) (user principal) (prediction bool) (amount uint))
  (ok true))

;; Public functions
(define-public (create-market (description (string-utf8 256)) (duration uint))
  (let ((market-id (var-get market-nonce)))
    (asserts! (not (var-get contract-paused)) (err u500))
    (asserts! (<= duration max-duration) err-invalid-duration)
    (asserts! (> duration u0) err-invalid-duration)
    
    (map-set markets
      { market-id: market-id }
      {
        creator: tx-sender,
        description: description,
        expiration: (+ block-height duration),
        total-stake: u0,
        resolved: false,
        outcome: false
      }
    )
    
    (var-set market-nonce (+ market-id u1))
    (try! (market-created-event market-id tx-sender description))
    (ok market-id)))

(define-public (make-prediction (market-id uint) (prediction bool) (stake-amount uint))
  (let ((market (unwrap! (map-get? markets { market-id: market-id }) err-market-not-found))
        (existing-prediction (map-get? predictions { market-id: market-id, user: tx-sender })))
    
    (asserts! (not (var-get contract-paused)) (err u500))
    (asserts! (>= stake-amount min-stake) err-invalid-stake)
    (asserts! (not (get resolved market)) err-market-expired)
    (asserts! (> (get expiration market) block-height) err-market-expired)
    (asserts! (is-none existing-prediction) err-already-predicted)
    
    (try! (contract-call? .trend-token transfer stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set predictions
      { market-id: market-id, user: tx-sender }
      {
        prediction: prediction,
        stake-amount: stake-amount,
        claimed: false
      }
    )
    
    (map-set markets
      { market-id: market-id }
      (merge market { total-stake: (+ (get total-stake market) stake-amount) })
    )
    
    (try! (prediction-made-event market-id tx-sender prediction stake-amount))
    (ok true)))

(define-public (resolve-market (market-id uint) (outcome bool))
  (let ((market (unwrap! (map-get? markets { market-id: market-id }) err-market-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get resolved market)) err-market-expired)
    
    (map-set markets
      { market-id: market-id }
      (merge market { resolved: true, outcome: outcome })
    )
    (ok true)))

(define-public (claim-reward (market-id uint))
  (let ((market (unwrap! (map-get? markets { market-id: market-id }) err-market-not-found))
        (prediction (unwrap! (map-get? predictions { market-id: market-id, user: tx-sender }) err-market-not-found)))
    
    (asserts! (get resolved market) err-not-resolved)
    (asserts! (not (get claimed prediction)) err-already-claimed)
    
    (if (is-eq (get prediction prediction) (get outcome market))
      (let ((reward-amount (* (get stake-amount prediction) u2)))
        (try! (as-contract (contract-call? .trend-token transfer reward-amount tx-sender tx-sender)))
        (map-set predictions
          { market-id: market-id, user: tx-sender }
          (merge prediction { claimed: true })
        )
        (ok reward-amount))
      (begin
        (map-set predictions
          { market-id: market-id, user: tx-sender }
          (merge prediction { claimed: true })
        )
        (ok u0)))))

;; Admin functions
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused false)
    (ok true)))
