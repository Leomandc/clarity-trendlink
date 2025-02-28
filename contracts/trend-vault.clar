;; TrendLink Vault Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant min-lock-period u1440) ;; 1 day in blocks
(define-constant reward-rate u100) ;; 1% per period

;; Error codes
(define-constant err-insufficient-stake (err u100))
(define-constant err-lock-period (err u101))
(define-constant err-no-stake (err u102))
(define-constant err-already-claimed (err u103))

;; Data structures
(define-map staking-positions
  { user: principal }
  {
    amount: uint,
    locked-until: uint,
    rewards: uint,
    last-reward-block: uint
  }
)

;; Public functions
(define-public (stake (amount uint))
  (let ((current-height block-height)
        (lock-until (+ current-height min-lock-period)))
    (asserts! (> amount u0) err-insufficient-stake)
    (try! (contract-call? .trend-token transfer amount tx-sender (as-contract tx-sender)))
    (map-set staking-positions
      { user: tx-sender }
      {
        amount: amount,
        locked-until: lock-until,
        rewards: u0,
        last-reward-block: current-height
      }
    )
    (ok true)))

(define-public (withdraw (amount uint))
  (let ((position (unwrap! (map-get? staking-positions { user: tx-sender }) err-no-stake))
        (current-height block-height))
    (asserts! (>= current-height (get locked-until position)) err-lock-period)
    (asserts! (>= (get amount position) amount) err-insufficient-stake)
    (try! (as-contract (contract-call? .trend-token transfer amount tx-sender tx-sender)))
    (map-set staking-positions
      { user: tx-sender }
      {
        amount: (- (get amount position) amount),
        locked-until: (get locked-until position),
        rewards: (get rewards position),
        last-reward-block: current-height
      }
    )
    (ok true)))

(define-public (claim-rewards)
  (let ((position (unwrap! (map-get? staking-positions { user: tx-sender }) err-no-stake))
        (current-height block-height)
        (reward-blocks (- current-height (get last-reward-block position)))
        (reward-amount (/ (* (get amount position) reward-rate reward-blocks) u10000)))
    (asserts! (> reward-amount u0) err-already-claimed)
    (try! (as-contract (contract-call? .trend-token mint reward-amount tx-sender)))
    (map-set staking-positions
      { user: tx-sender }
      {
        amount: (get amount position),
        locked-until: (get locked-until position),
        rewards: (+ (get rewards position) reward-amount),
        last-reward-block: current-height
      }
    )
    (ok reward-amount)))
