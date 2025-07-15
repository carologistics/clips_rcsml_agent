(defrule unwatch-refbox-spam
=>
  (unwatch facts protobuf-msg)
)

; ------------------------------------------------------------------------------

(deftemplate protobuf-peer
    (slot name (type SYMBOL))
    (slot peer-id (type INTEGER))
)

(deftemplate refbox-gamestate
    (slot state (type SYMBOL) (allowed-values NOT_INIT INIT WAIT-START RUNNING PAUSED))
    (slot phase (type SYMBOL) (allowed-values PRE_GAME SETUP EXPLORATION PRODUCTION POST_GAME))
    (slot points (type INTEGER))
    (slot points-other (type INTEGER))
    (slot team (type STRING))
    (slot team-other (type STRING))
    (slot team-color (type SYMBOL) (allowed-values NOT-SET CYAN MAGENTA) (default NOT-SET))
    (slot field-width (type INTEGER))
    (slot field-height (type INTEGER))
    (slot field-mirrored (type SYMBOL) (allowed-values FALSE TRUE))
    (slot game-time (type FLOAT) (default 0.0))
)

(deftemplate refbox-machineinfo
    (slot name (type SYMBOL))
    (slot type (type SYMBOL))
    (slot team-color (type SYMBOL) (allowed-values CYAN MAGENTA))
    (slot state (type SYMBOL))
    (slot zone (type SYMBOL))
    (slot rotation (type INTEGER))
    (slot ground-truth (type SYMBOL) (allowed-values TRUE FALSE))
    (multislot colors (type SYMBOL))
)

(deftemplate refbox-ringinfo
    (slot color (type SYMBOL))
    (slot cost (type INTEGER))
)

(deftemplate refbox-orderinfo
    (slot id (type INTEGER))
    (slot workpiece (type SYMBOL))
    (slot complexity (type SYMBOL))

    (slot base-color (type SYMBOL))
    (multislot ring-colors (type SYMBOL))
    (slot cap-color (type SYMBOL))

    (slot quantity-requested (type INTEGER))
    (slot quantity-delivered-magenta (type INTEGER))
    (slot quantity-delivered-cyan (type INTEGER))

    (slot delivery-begin (type INTEGER))
    (slot delivery-end (type INTEGER))
    (slot competitive (type SYMBOL))

    (slot state (type SYMBOL) (default OPEN) (allowed-values OPEN ACTIVE COMPLETED CANCELLED))
)

(deftemplate refbox-robotinfo
    (slot name (type SYMBOL))
    (slot state (type SYMBOL) (allowed-values ACTIVE MAINTENANCE))
)

; ------------------------------------------------------------------------------

(defrule refbox-initialise
    "Enable local peer connection to the unencrypted refbox channel"
    (configured)
    (not (refbox-initialised))
    (confval (path "/refbox/peer_address") (value ?peer-address))
    (confval (path "/refbox/peer_send_port") (value ?peer-send-port))
    (confval (path "/refbox/peer_recv_port") (value ?peer-recv-port))
    (not (protobuf-peer (name refbox-public)))
    =>
    (printout info "Enabling local peer (public) " ?peer-address " " ?peer-send-port " " ?peer-recv-port crlf)
    (bind ?peer-id (pb-peer-create-local ?peer-address ?peer-send-port ?peer-recv-port))
    (assert (protobuf-peer (name refbox-public) (peer-id ?peer-id)))
    (assert (refbox-initialised))
)

(defrule refbox-enable-encrypted-peer-cyan
    "Enable local peer connection to the encrypted team channel (CYAN)"
    (refbox-gamestate (team-color ?team-color&CYAN))
    (protobuf-peer (name refbox-public))
    (confval (path "/refbox/peer_address") (value ?address))
    (confval (path "/refbox/crypto_key") (value ?key))
    (confval (path "/refbox/cipher") (value ?cipher))
    (confval (path "/refbox/cyan_recv_port") (value ?cyan-recv-port))
    (confval (path "/refbox/cyan_send_port") (value ?cyan-send-port))
    (not (protobuf-peer (name refbox-private)))
    =>
    (printout info "Enabling local peer (cyan only)" ?address " " ?cyan-send-port " " ?cyan-recv-port " " ?key " " ?cipher crlf)
    (bind ?peer-id (pb-peer-create-local-crypto ?address ?cyan-send-port ?cyan-recv-port ?key ?cipher))
    (assert (protobuf-peer (name refbox-private) (peer-id ?peer-id)))
)

(defrule refbox-enable-encrypted-peer-magenta
    "Enable local peer connection to the encrypted team channel (MAGENTA)"
    (refbox-gamestate (team-color ?team-color&MAGENTA))
    (protobuf-peer (name refbox-public))
    (confval (path "/refbox/peer_address") (value ?address))
    (confval (path "/refbox/crypto_key") (value ?key))
    (confval (path "/refbox/cipher") (value ?cipher))
    (confval (path "/refbox/magenta_recv_port") (value ?magenta-recv-port))
    (confval (path "/refbox/magenta_send_port") (value ?magenta-send-port))
    (not (protobuf-peer (name refbox-private)))
    =>
    (printout info "Enabling local peer (magenta only)" crlf)
    (bind ?peer-id (pb-peer-create-local-crypto ?address ?magenta-send-port ?magenta-recv-port ?key ?cipher))
    (assert (protobuf-peer (name refbox-private) (peer-id ?peer-id)))
)

(defrule refbox-gamestate-init
    "Assert the initial game state."
    (refbox-initialised)
    (not (refbox-gamestate))
    =>
    (assert (refbox-gamestate
        (state NOT_INIT)
        (phase PRE_GAME)
        (team-color NOT-SET)
        (team "")
        (team-other "")
        (points 0)
        (points-other 0)
        (field-width 0)
        (field-height 0)
        (field-mirrored FALSE)
        (game-time 0.0)
    ))
)

; ------------------------------------------------------------------------------


(defrule refbox-gamestate-update
    ?pb-msg <- (protobuf-msg (type "llsf_msgs.GameState") (ptr ?p))
    ?gs <- (refbox-gamestate)
    (confval (path "/refbox/team_name") (value ?team))
    =>
    ;update game-time
    (bind ?time (pb-field-value ?p "game_time"))
    (bind ?sec (pb-field-value ?time "sec"))
    (bind ?nsec (pb-field-value ?time "nsec"))
    (bind ?game-time(+ ?sec (/  ?nsec 1000000000)))

    ;update game-state
    (bind ?team-other "")
    (bind ?points-other 0)
    (bind ?points 0)
    (bind ?team-color NOT-SET)
    (if (and (pb-has-field ?p "team_cyan")
            (eq (pb-field-value ?p "team_cyan") ?team))
        then
        (bind ?team-color CYAN)
        (bind ?points (pb-field-value ?p "points_cyan"))
        (if (pb-has-field ?p "team_magenta") then
            (bind ?team-other (pb-field-value ?p "team_magenta"))
            (bind ?points-other (pb-field-value ?p "points_magenta"))
        )
    )
    (if (and (pb-has-field ?p "team_magenta")
            (eq (pb-field-value ?p "team_magenta") ?team))
        then
        (bind ?team-color MAGENTA)
        (bind ?points (pb-field-value ?p "points_magenta"))
        (if (pb-has-field ?p "team_cyan") then
            (bind ?team-other (pb-field-value ?p "team_cyan"))
            (bind ?points-other (pb-field-value ?p "points_cyan"))
        )
    )
    (if (and (neq ?team-color ?team-color) (neq ?team-color NOT-SET)) then
        (printout warn "Switching team color from " ?team-color " to " ?team-color crlf)
    )
    (modify ?gs
        (team ?team)
        (team-other ?team-other)
        (team-color ?team-color)
        (points ?points)
        (points-other ?points-other)
        (state (pb-field-value ?p "state"))
        (phase (pb-field-value ?p "phase"))
        (field-height (pb-field-value ?p "field_height"))
        (field-width (pb-field-value ?p "field_width"))
        (field-mirrored (pb-field-value ?p "field_mirrored"))
        (game-time ?game-time)
    )
    (retract ?pb-msg)
)

(defrule refbox-machineinfo-update
    ?pb-msg <- (protobuf-msg (type "llsf_msgs.MachineInfo") (ptr ?p))
    (refbox-gamestate (team-color ?team-color))
    =>
    (bind ?list (pb-field-list ?p "machines"))
    (foreach ?m ?list
        (bind ?m-name (sym-cat (pb-field-value ?m "name")))
        (bind ?m-type (sym-cat (pb-field-value ?m "type")))
        (bind ?m-team (sym-cat (pb-field-value ?m "team_color")))
        (bind ?m-state (sym-cat (pb-field-value ?m "state")))

        (bind ?rot  FALSE)
        (bind ?zone NOT-SET)
        (bind ?ground-truth FALSE)
        (if (pb-has-field ?m "rotation") then
            (bind ?rot  (pb-field-value ?m "rotation"))
        )
        (if (pb-has-field ?m "zone") then
            (bind ?zone (pb-field-value ?m "zone"))
        )
        (if (and (neq ?zone NOT-SET) (neq ?rot FALSE)) then
            (bind ?ground-truth TRUE)
        )
        (bind ?colors (create$))
        (if (eq ?m-type RS) then
            (bind ?colors (pb-field-list ?m "ring_colors"))
        )

        ; update the machine info fact
        (if (any-factp ((?om refbox-machineinfo)) (eq ?om:name ?m-name)) then
            (do-for-all-facts ((?om refbox-machineinfo)) (eq ?om:name ?m-name)
                (modify ?om (name ?m-name) (type ?m-type) (team-color ?m-team) (state ?m-state) (zone ?zone) (rotation ?rot) (ground-truth ?ground-truth) (colors $?colors))
            )
        else
            (assert (refbox-machineinfo (name ?m-name) (type ?m-type) (team-color ?m-team) (state ?m-state) (zone ?zone) (rotation ?rot) (ground-truth ?ground-truth) (colors $?colors)))
        )
    )
    (retract ?pb-msg)
)

(defrule refbox-ringinfo-update
  ?pb-msg <- (protobuf-msg (type "llsf_msgs.RingInfo") (ptr ?p))
  =>
  (foreach ?r (pb-field-list ?p "rings")
    (bind ?color (pb-field-value ?r "ring_color"))
    (bind ?raw-material (pb-field-value ?r "raw_material"))

    (if (any-factp ((?rs refbox-ringinfo)) (eq ?rs:color ?color)) then
        (do-for-all-facts ((?rs refbox-ringinfo)) (eq ?rs:color ?color)
            (modify ?rs (color ?color) (cost ?raw-material))
        )
    else
        (assert (refbox-ringinfo (color ?color) (cost ?raw-material)))
    )
  )
  (retract ?pb-msg)
)

(defrule refbox-robotinfo-update
    ?pb-msg <- (protobuf-msg (type "llsf_msgs.RobotInfo") (ptr ?r))
    (refbox-gamestate (team ?team) (team-color ?team-color))
    =>
    (foreach ?p (pb-field-list ?r "robots")
        (if (eq ?team-color (pb-field-value ?p "team_color")) then
            (bind ?state (sym-cat (pb-field-value ?p "state")))
            (bind ?name (sym-cat (pb-field-value ?p "name")))

            (if (any-factp ((?robot refbox-robotinfo)) (eq ?robot:name ?name)) then
                (do-for-all-facts ((?robot refbox-robotinfo)) (eq ?robot:name ?name)
                    (modify ?robot (state ?state))
                )
            else
                (assert (refbox-robotinfo (name ?name) (state ?state)))
            )
        )
    )
    (retract ?pb-msg)
)

(defrule refbox-orderinfo-update
    ?pb-msg <- (protobuf-msg (type "llsf_msgs.OrderInfo") (ptr ?ptr))
    (refbox-gamestate (team ?team) (team-color ?team-color))
    =>
    (foreach ?o (pb-field-list ?ptr "orders")
        (bind ?id (pb-field-value ?o "id"))
        (bind ?competitive (pb-field-value ?o "competitive"))

        (bind ?quantity-requested (pb-field-value ?o "quantity_requested"))
        (bind ?begin (pb-field-value ?o "delivery_period_begin"))
        (bind ?end (pb-field-value ?o "delivery_period_end"))
        (bind ?qd-magenta (pb-field-value ?o "quantity_delivered_magenta"))
        (bind ?qd-cyan (pb-field-value ?o "quantity_delivered_cyan"))

        (bind ?complexity (pb-field-value ?o "complexity"))
        (bind ?base (pb-field-value ?o "base_color"))
        (bind ?cap (pb-field-value ?o "cap_color"))
        (bind ?ring-colors (pb-field-list ?o "ring_colors"))

        (if (any-factp ((?order refbox-orderinfo)) (eq ?order:id ?id)) then
            (do-for-all-facts ((?order refbox-orderinfo)) (eq ?order:id ?id)
                (modify ?order  (id ?id)
                                (complexity ?complexity)
                                (competitive ?competitive)
                                (quantity-requested ?quantity-requested)
                                (delivery-begin ?begin)
                                (delivery-end ?end)
                                (base-color ?base)
                                (ring-colors ?ring-colors)
                                (cap-color ?cap)
                                (quantity-delivered-magenta ?qd-magenta)
                                (quantity-delivered-cyan ?qd-cyan)
                            )
            )
        else
            (assert (refbox-orderinfo
                (id ?id)
                (complexity ?complexity)
                (competitive ?competitive)
                (quantity-requested ?quantity-requested)
                (delivery-begin ?begin)
                (delivery-end ?end)
                (base-color ?base)
                (ring-colors ?ring-colors)
                (cap-color ?cap)
                (quantity-delivered-magenta ?qd-magenta)
                (quantity-delivered-cyan ?qd-cyan)
            ))
        )

    )
    (retract ?pb-msg)
)

(defrule refbox-gamestate-print
    (refbox-gamestate
        (game-time ?game-time)
        (state ?state)
        (phase ?phase))
    =>
    (printout warn ?game-time ": " "(" ?state "|" ?phase ")" crlf)
)

; -----------------------------------------------------------------------------

(deffunction refbox-instruct-dispense-bs (?mps ?team-color ?peer-id ?color ?side)
    (bind ?machine-instruction (pb-create "llsf_msgs.PrepareMachine"))
    (pb-set-field ?machine-instruction "team_color" ?team-color)
    (bind ?bs-inst (pb-create "llsf_msgs.PrepareInstructionBS"))
    (pb-set-field ?bs-inst "side" ?side)
    (pb-set-field ?bs-inst "color" ?color)
    (pb-set-field ?machine-instruction "instruction_bs" ?bs-inst)
    (pb-set-field ?machine-instruction "machine" (str-cat ?mps))
    (pb-broadcast ?peer-id ?machine-instruction)
    (pb-destroy ?machine-instruction)
    (printout warn "Sent Prepare Msg for " ?mps  crlf)
)

(deffunction refbox-instruct-mount-cs (?mps ?team-color ?peer-id)
    (bind ?machine-instruction (pb-create "llsf_msgs.PrepareMachine"))
    (pb-set-field ?machine-instruction "team_color" ?team-color)
    (bind ?cs-inst (pb-create "llsf_msgs.PrepareInstructionCS"))
    (pb-set-field ?cs-inst "operation"  MOUNT_CAP)
    (pb-set-field ?machine-instruction "instruction_cs" ?cs-inst)
    (pb-set-field ?machine-instruction "machine" (str-cat ?mps))
    (pb-broadcast ?peer-id ?machine-instruction)
    (pb-destroy ?machine-instruction)
    (printout warn "Sent Prepare Msg for " ?mps crlf)
)

(deffunction refbox-instruct-unmount-cs (?mps ?team-color ?peer-id)
    (bind ?machine-instruction (pb-create "llsf_msgs.PrepareMachine"))
    (pb-set-field ?machine-instruction "team_color" ?team-color)
    (bind ?cs-inst (pb-create "llsf_msgs.PrepareInstructionCS"))
    (pb-set-field ?cs-inst "operation"  RETRIEVE_CAP)
    (pb-set-field ?machine-instruction "instruction_cs" ?cs-inst)
    (pb-set-field ?machine-instruction "machine" (str-cat ?mps))
    (pb-broadcast ?peer-id ?machine-instruction)
    (pb-destroy ?machine-instruction)
    (printout warn "Sent Prepare Msg for " ?mps crlf)
)

(deffunction refbox-instruct-mount-rs (?mps ?team-color ?peer-id ?color)
    (bind ?machine-instruction (pb-create "llsf_msgs.PrepareMachine"))
    (pb-set-field ?machine-instruction "team_color" ?team-color)
    (bind ?rs-inst (pb-create "llsf_msgs.PrepareInstructionRS"))
    (pb-set-field ?rs-inst "ring_color" ?color)
    (pb-set-field ?machine-instruction "instruction_rs" ?rs-inst)
    (pb-set-field ?machine-instruction "machine" (str-cat ?mps))
    (pb-broadcast ?peer-id ?machine-instruction)
    (pb-destroy ?machine-instruction)
    (printout warn "Sent Prepare Msg for " ?mps crlf)
)

(deffunction refbox-instruct-deliver-ds (?mps ?team-color ?peer-id ?order-id)
    (bind ?machine-instruction (pb-create "llsf_msgs.PrepareMachine"))
    (pb-set-field ?machine-instruction "team_color" ?team-color)
    (bind ?ds-inst (pb-create "llsf_msgs.PrepareInstructionDS"))
    (pb-set-field ?ds-inst "order_id" ?order-id)
    (pb-set-field ?machine-instruction "instruction_ds" ?ds-inst)
    (pb-set-field ?machine-instruction "machine" (str-cat ?mps))
    (pb-broadcast ?peer-id ?machine-instruction)
    (pb-destroy ?machine-instruction)
    (printout warn "Sent Prepare Msg for " ?mps  crlf)
)
