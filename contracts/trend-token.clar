;; TrendLink Token Contract

(define-fungible-token trend-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant token-name "TrendLink Token")
(define-constant token-symbol "TREND")
(define-constant token-decimals u6)

;; Error codes
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-not-authorized (err u102))
(define-constant err-invalid-amount (err u103))

;; Data vars
(define-data-var total-supply uint u0)

;; SIP-010 Functions
(define-read-only (get-name)
  (ok token-name))

(define-read-only (get-symbol)
  (ok token-symbol))

(define-read-only (get-decimals)
  (ok token-decimals))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

;; Token functions
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (var-set total-supply (+ (var-get total-supply) amount))
    (ft-mint? trend-token amount recipient)))

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-authorized)
    (asserts! (> amount u0) err-invalid-amount)
    (ft-transfer? trend-token amount sender recipient)))

(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) err-not-authorized)
    (asserts! (> amount u0) err-invalid-amount)
    (var-set total-supply (- (var-get total-supply) amount))
    (ft-burn? trend-token amount owner)))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance trend-token account)))
