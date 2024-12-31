;; SwapX - Decentralized Token Swap Protocol

(define-trait ft-trait
    (
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        (get-name () (response (string-ascii 32) uint))
        (get-symbol () (response (string-ascii 32) uint))
        (get-decimals () (response uint uint))
        (get-balance (principal) (response uint uint))
        (get-total-supply () (response uint uint))
        (get-token-uri () (response (optional (string-utf8 256)) uint))
    )
)

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))

(define-data-var contract-owner principal tx-sender)
(define-map pools 
    {token-a: principal, token-b: principal}
    {balance-a: uint, balance-b: uint, total-shares: uint}
)
(define-map shares-balance
    {pool: {token-a: principal, token-b: principal}, owner: principal}
    uint
)

(define-public (initialize-pool (token-a <ft-trait>) (token-b <ft-trait>) (amount-a uint) (amount-b uint))
    (let
        (
            (pool-exists (get-pool-details (contract-of token-a) (contract-of token-b)))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none pool-exists) ERR-INVALID-AMOUNT)
        (asserts! (> amount-a u0) ERR-INVALID-AMOUNT)
        (asserts! (> amount-b u0) ERR-INVALID-AMOUNT)
        
        (try! (contract-call? token-a transfer amount-a tx-sender (as-contract tx-sender) none))
        (try! (contract-call? token-b transfer amount-b tx-sender (as-contract tx-sender) none))
        
        (map-set pools
            {token-a: (contract-of token-a), token-b: (contract-of token-b)}
            {balance-a: amount-a, balance-b: amount-b, total-shares: amount-a}
        )
        
        (map-set shares-balance
            {pool: {token-a: (contract-of token-a), token-b: (contract-of token-b)}, owner: tx-sender}
            amount-a
        )
        (ok true)
    )
)

(define-read-only (get-pool-details (token-a principal) (token-b principal))
    (map-get? pools {token-a: token-a, token-b: token-b})
)

(define-public (swap-tokens (token-a <ft-trait>) (token-b <ft-trait>) (amount-in uint))
    (let
        (
            (pool (unwrap! (get-pool-details (contract-of token-a) (contract-of token-b)) ERR-INVALID-AMOUNT))
            (balance-a (get balance-a pool))
            (balance-b (get balance-b pool))
            (amount-out (/ (* amount-in balance-b) (+ amount-in balance-a)))
        )
        (asserts! (> amount-in u0) ERR-INVALID-AMOUNT)
        (asserts! (> amount-out u0) ERR-INVALID-AMOUNT)
        
        (try! (contract-call? token-a transfer amount-in tx-sender (as-contract tx-sender) none))
        (as-contract (try! (contract-call? token-b transfer amount-out (as-contract tx-sender) tx-sender none)))
        
        (map-set pools
            {token-a: (contract-of token-a), token-b: (contract-of token-b)}
            {
                balance-a: (+ balance-a amount-in),
                balance-b: (- balance-b amount-out),
                total-shares: (get total-shares pool)
            }
        )
        (ok amount-out)
    )
)

(define-read-only (get-shares-balance (token-a principal) (token-b principal) (owner principal))
    (default-to u0 
        (map-get? shares-balance 
            {pool: {token-a: token-a, token-b: token-b}, owner: owner}
        )
    )
)