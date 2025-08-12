; Express has a different UART start function, see the documentation for details
(if (eq (sysinfo 'hw-type) 'hw-express)
    (uart-start 1 20 21 9600)
    (uart-start 9600)
)

(define uart-buf-rx (array-create 21))
(def throttle 0)
(def wheel-diameter 0)
(def speed-x10 0)
(def impulses 6000)
(def current-mode 0)
(def old-current-mode 0)
(def switch-times 0)
(def adc-detached 0)
(def temp-times 0)
(def temp-buffer 0.0)

; TX buffer for response
(define uart-buf-tx (array-create 14))

; Function to initialize buffer with data
(defun init-buffer (buffer data)
    (looprange i 0 (length data)
        (bufset-u8 buffer i (ix data i))
    )
)

; Initialize TX buffer with fixed data
(init-buffer uart-buf-tx '(0x02 0x0E 0x01 0x00 0x80 0x00 0x00 0x00
                           0x00 0x50 0x00 0x00 0xFF 0x00)) ; Last byte (CRC) will be calculated

; CRC check function (analog of bool check_crc)
(defun check-crc () {
    ; Check if byte 0 is 1 and byte 1 is 20
    (if (and (= (bufget-u8 uart-buf-rx 0) 1)
             (= (bufget-u8 uart-buf-rx 1) 20)) {
        (let ((crc 0)) {
            ; Calculate XOR of all bytes except the last one
            (looprange i 0 19
                (setq crc (bitwise-xor crc (bufget-u8 uart-buf-rx i)))
            )
            ; Compare with the last byte (CRC)
            (= crc (bufget-u8 uart-buf-rx 19))
        })
    } {
        ; Return false if header bytes are incorrect
        nil
    })
})

; Function to calculate impulses based on speed and wheel diameter
(defun calculate-impulses () {
    (if (or (= speed-x10 0) (= wheel-diameter 0))
        (setq impulses 6000)  ; Default value when speed or diameter is 0
        (let ((circumference-m (* 3.14159 wheel-diameter 0.00254))  ; Convert inches to meters
              (speed-mps (/ speed-x10 36.0)))                       ; Convert km/h*10 to m/s
            (let ((rotations-per-second (/ speed-mps circumference-m))) {
                (if (= rotations-per-second 0)
                    (setq impulses 6000)  ; Fallback value
                    (setq impulses (to-i (/ 1000.0 rotations-per-second)))
                )
            })
        )
    )
})

; Function to calculate CRC and send TX buffer
(defun send-response (){
    ; Update impulses in TX buffer
    (let ((pulses impulses)) {
        ; If speed is 0, set pulses to 0x1770
        (if (= speed-x10 0)
            (setq pulses 0x1770)
        )
        ; Set pulses in TX buffer (big-endian: high byte first)
        (bufset-u8 uart-buf-tx 8 (shr pulses 8))   ; High byte
        (bufset-u8 uart-buf-tx 9 (bitwise-and pulses 0xFF))          ; Low byte
    })

    (let ((crc 0)) {
        ; Calculate XOR of first 13 bytes
        (looprange i 0 13
            (setq crc (bitwise-xor crc (bufget-u8 uart-buf-tx i)))
        )
        ; Set CRC as last byte
        (bufset-u8 uart-buf-tx 13 crc)
        ; Send the buffer
        (uart-write uart-buf-tx)
        ;(print (str-merge "Response sent with CRC: 0x" (str-from-n crc "%02X")))
    })
})

(defun play-stop () {
    (sleep 0.3)
    (foc-play-stop)
})

(defun read-thd ()
    (loopwhile t {
            (uart-read-bytes uart-buf-rx 20 0)
            ; Check if first byte is 1 and CRC is valid
            (if (check-crc)
                (progn
                    ; Extract throttle value from bytes 16 and 17 (little-endian)
                    (setq throttle (+ (bufget-u8 uart-buf-rx 17)
                                     (* (bufget-u8 uart-buf-rx 16) 256)))

                    (setq wheel-diameter (+ (bufget-u8 uart-buf-rx 8)
                                     (* (bufget-u8 uart-buf-rx 7) 256)))

                    (setq current-mode (bufget-u8 uart-buf-rx 4))
                    (if (< current-mode old-current-mode)
                        (progn
                            (setq switch-times (+ switch-times 1))
                            (if (= switch-times 3)
                                (progn
                                    (conf-set 'max-speed (/ 50 3.6))
                                    (print "Max speed set to 50 km/h")
                                    (foc-play-tone 0 1000 15)
                                    (spawn 150 play-stop)
                                )
                            )
                        )
                    )
                    (setq old-current-mode current-mode)

                    ; Calculate impulses based on speed and wheel diameter
                    ; Get current speed in m/s and convert to km/h*10
                    (let ((speed-ms (get-speed))) {
                        (setq speed-x10 (to-i (* speed-ms 36))) ; Convert m/s to km/h*10
                    })
                    (calculate-impulses)
                    ;(print (str-merge "Throttle: " (to-str throttle)))
                    ;(print (str-merge "Wheel diameter: " (to-str wheel-diameter)))
                    ;(print (str-merge "Calculated impulses: " (to-str impulses)))

                    ; Send response back with CRC
                    (send-response)

                    ;(print "CRC OK - Data is valid:")
                    ;(print uart-buf-rx)
                )
                (progn
                    (print "CRC ERROR - Data is corrupted!")
                    (setq throttle 0)
                    (print uart-buf-rx)
                    (uart-read-bytes uart-buf-rx 1 0)
                    (sleep 0.1)
                )
            )
            (let ((throttle-normalized (/ throttle 300.0))) {
                ;(set-current-rel throttle-normalized)
                ; override ADC1
                (if (and (> throttle-normalized 0.5) (= adc-detached 0`))
                    (progn
                        (setq adc-detached 1)
                        (app-adc-detach 1 2)
                        (print "ADC detached")
                    )
                )
                (if (= adc-detached 1)
                    (progn
                        (app-adc-override 0 throttle-normalized)
                        (print (str-merge "Current set to: " (to-str throttle-normalized)))
                    )
                )
            })
            ; Small delay before next read
            (sleep 0.1)
}))



(defun read-temp ()
    (loopwhile t {
        (let ((temp (setq temp (* (get-adc 3) 100))))
            (progn
                (print (to-str temp))
                (print (to-str temp-buffer))
                (setq temp-buffer (+ temp-buffer temp))
                (setq temp-times (+ temp-times 1))
                (print (to-str temp-buffer))
                (print (to-str temp-times))
                
                (if (> temp-times 20)
                    (progn
                        (let ((out-temp (/ temp-buffer temp-times)))
                            (progn
                                (override-temp-motor out-temp)
                                (print (str-merge "Temp: " (to-str out-temp)))
                            )
                        )
                        (setq temp-buffer 0)
                        (setq temp-times 0)
                    )
                )
            )
        )
        (sleep 0.1)
    })
)

(conf-set 'max-speed (/ 25 3.6))
(spawn 150 read-thd) ; Run reader in its own thread
(spawn 150 read-temp) ; Run temperature reader in its own thread for LM35Z
;(override-temp-motor 0)
