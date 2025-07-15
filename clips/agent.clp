(defrule unwatch-spam
    =>
    (unwatch rules  refbox-robotinfo-update refbox-ringinfo-update refbox-machineinfo-update executor-recv-feedback  protobuf-cleanup-message  refbox-orderinfo-update refbox-gamestate-update)
)

(deftemplate agent-active-orders
    (slot id)
    (slot status (type SYMBOL) (allowed-values ACTIVE COMPLETED FAILED))
)

(deftemplate agent-action
    (slot name (type SYMBOL))
    (slot type (type SYMBOL))
    (multislot args (type SYMBOL))
    (slot id (type INTEGER))
    (slot status (type SYMBOL) (default PENDING) (allowed-values PENDING ACTIVE COMPLETED FAILED))
    (multislot tasks (type SYMBOL))
)

;-------------------------------------------------------------------------------

(defrule configure
    (not (configured))
    =>
    (unwatch facts time)
    (unwatch rules time-retract)
    (bind ?share-dir (ament-index-get-package-share-directory "clips_rcsml_agent"))
    (config-load (str-cat ?share-dir "/config/agent_config.yaml") "/")

    (assert (configured))
    (printout t "Loaded the configuration" crlf)
)

(defrule initialised
    (not (initialised))
    (refbox-initialised)
    (executor-initialised)
    =>
    (printout t "The agent is initialised" crlf)

    (assert (initialised))
)

;-------------------------------------------------------------------------------

(defrule agent-order-tasks
    (initialised)
    (refbox-orderinfo (id ?id)
                    (complexity ?complexity)
                    (base-color ?base)
                    (ring-colors $?ring-colors)
                    (cap-color ?cap))
    (not (agent-active-orders ))
    (refbox-ringinfo)
    =>
    (printout green "Starting order from refbox: " ?id crlf "Complexity: " ?complexity
             ", base color: " ?base
             ", ring colors: " ?ring-colors
             ", cap color: " ?cap crlf)
    (assert (agent-active-orders (id ?id) (status ACTIVE)))
)

(defrule agent-order-create-actions
    (agent-active-orders (id ?order-id) (status ACTIVE))
    (refbox-orderinfo (id ?order-id)
                    (complexity ?complexity)
                    (base-color ?base)
                    (ring-colors $?ring-colors)
                    (cap-color ?cap))
    (refbox-gamestate (team-color ?team-color))
    (not (agent-action))
    =>
    (printout green "Creating action-plan for order: " ?order-id crlf)


    (if (eq ?team-color CYAN) then
        (if (eq ?cap CAP_BLACK) then
            (bind ?cs "C-CS2")
        else
            (bind ?cs "C-CS1")
        )
    else
        (if (eq ?cap CAP_BLACK) then
            (bind ?cs "M-CS2")
        else
            (bind ?cs "M-CS1")
        )
    )

    (bind ?action-id 1)

    (assert (agent-action (name PREPARE-CAP) (type SEQUENCE) (args ?cs ?cap) (id ?action-id) (tasks MoveMachineInput BufferStation Instruct MoveMachineOutput Retrieve)))
    (bind ?action-id (+ 1 ?action-id))

    (assert (agent-action (name DISCARD-CC) (type SEQUENCE) (id ?action-id) (tasks MoveMachineInput Deliver Instruct)))
    (bind ?action-id (+ 1 ?action-id))

    (assert (agent-action (name GET-BASE) (type SEQUENCE) (args ?base) (id ?action-id) (tasks Instruct MoveMachineInput Retrieve)))
    (bind ?action-id (+ 1 ?action-id))

    (if (not (eq ?complexity C0)) then
        (foreach ?ring-color ?ring-colors
            (do-for-all-facts ((?cost refbox-ringinfo)) (eq ?cost:color ?ring-color)
                (do-for-fact ((?mps refbox-machineinfo)) (member$ ?ring-color ?mps:colors)
                    (assert (agent-action (name PUT-WP) (type SEQUENCE) (args ?mps:name INPUT) (id ?action-id) (tasks MoveMachineInput Deliver)))
                    (bind ?action-id (+ 1 ?action-id))
                    (if (> ?cost:cost 0) then
                        (bind ?repeats ?cost:cost)
                        (while (> ?repeats 0)
                            (assert (agent-action (name GET-BASE) (type SEQUENCE) (args BASE_RED) (id ?action-id) (tasks Instruct MoveMachineInput Retrieve)))
                            (bind ?action-id (+ 1 ?action-id))
                            (assert (agent-action (name PAY-RING) (type SEQUENCE) (args ?mps:name) (id ?action-id) (tasks MoveMachineInput Deliver)))
                            (bind ?action-id (+ 1 ?action-id))
                            (bind ?repeats (- ?repeats 1))
                        )
                    )
                    (assert (agent-action (name MOUNT-RING) (type SEQUENCE) (args ?mps:name ?ring-color) (id ?action-id) (tasks Instruct MoveMachineOutput Retrieve)))
                    (bind ?action-id (+ 1 ?action-id))
                )
            )
        )
    )

    (assert (agent-action (name PUT-WP) (type SEQUENCE) (args ?cs INPUT) (id ?action-id) (tasks MoveMachineInput Deliver)))
    (bind ?action-id (+ 1 ?action-id))
    (assert (agent-action (name MOUNT-CAP) (type SEQUENCE) (args ?cs) (id ?action-id) (tasks Instruct MoveMachineOutput Retrieve)))
    (bind ?action-id (+ 1 ?action-id))
    (assert (agent-action (name DELIVER) (type SEQUENCE) (args ?order-id) (id ?action-id) (tasks MoveMachineInput Deliver Instruct)))
    (bind ?action-id (+ 1 ?action-id))

    (printout warn "Created action-plan. Consisting of " ?action-id " tasks" crlf)
)


;-------------------------------------------------------------------------------

(defrule agent-actions-start
    ?a <- (agent-action (id ?action-id) (status PENDING) (name ?action-name))
    (not (agent-action (id ?other-id&:(> ?action-id ?other-id)) (status PENDING|ACTIVE)))
    =>
    (printout green "Starting action: " ?action-name " with id: " ?action-id crlf)
    (modify ?a (status ACTIVE))
)

(defrule agent-actions-end
    ?a <- (agent-action (id ?action-id) (status ACTIVE) (name ?action-name) (tasks ))
    =>
    (printout green "Action " ?action-name " has no tasks left, completed!" crlf)
    (modify ?a (status COMPLETED))
)

(defrule agent-actions-abort-error
    ?a <- (agent-action (id ?action-id) (status ACTIVE) (name ?action-name))
    (executor-task (status FAILED))
    =>
    (modify ?a (status FAILED))
    (printout red "Action " ?action-name " with id: " ?action-id " has failed due to an executor error!" crlf)
)

(defrule agent-actions-next-task-prepare-cap
    ?a <- (agent-action (id ?action-id) (name PREPARE-CAP) (status ACTIVE) (args ?mps ?cap-color) (tasks ?task $?tasks))
    (not (executor-task (status SENT)))
    (protobuf-peer (name ROBOT1) (peer-id ?peer-id))
    (refbox-gamestate (team-color ?team-color))
    (protobuf-peer (name refbox-private) (peer-id ?refbox-peer-id))
    =>
    (printout green "Preparing cap: " ?cap-color " on machine: " ?mps crlf)
    (if (eq ?task MoveMachineInput) then
        (executor-send-MoveMachine ?peer-id ?team-color 1 ?mps INPUT)
    )
    (if (eq ?task BufferStation) then
        (executor-send-BufferStation ?peer-id ?team-color 1 ?mps 1)
    )
    (if (eq ?task Instruct) then
        (printout green "Instructing MPS to prepare cap: " ?cap-color crlf)
        (refbox-instruct-unmount-cs ?mps ?team-color ?refbox-peer-id)
    )
    (if (eq ?task MoveMachineOutput) then
        (executor-send-MoveMachine ?peer-id ?team-color 1 ?mps OUTPUT)
    )
    (if (eq ?task Retrieve) then
        (executor-send-Retrieve ?peer-id ?team-color 1 ?mps OUTPUT)
    )

    (modify ?a (tasks ?tasks))
)

(defrule agent-actions-next-task-discard-cc
    ?a <- (agent-action (id ?action-id) (name DISCARD-CC) (status ACTIVE) (tasks ?task $?tasks))
    (not (executor-task (status SENT)))
    (protobuf-peer (name ROBOT1) (peer-id ?peer-id))
    (refbox-gamestate (team-color ?team-color))
    (protobuf-peer (name refbox-private) (peer-id ?refbox-peer-id))
    =>
    (bind ?mps "")
    (if (eq ?team-color CYAN) then
        (bind ?mps "C-DS")
    else
        (bind ?mps "M-DS")
    )
    (printout green "Discarding carrier on machine: " ?mps crlf)
    (if (eq ?task MoveMachineInput) then
        (executor-send-MoveMachine ?peer-id ?team-color 1 ?mps INPUT)
    )
    (if (eq ?task Deliver) then
        (executor-send-Deliver ?peer-id ?team-color 1 ?mps INPUT)
    )
    (if (eq ?task Instruct) then
        (printout green "Instructing MPS to discard carrier" crlf)
        (refbox-instruct-deliver-ds ?mps ?team-color ?refbox-peer-id 0)
    )
    (modify ?a (tasks ?tasks))
)

(defrule agent-actions-next-task-get-base
    ?a <- (agent-action (id ?action-id) (name GET-BASE) (status ACTIVE) (args ?base-color) (tasks ?task $?tasks))
    (not (executor-task (status SENT)))
    (protobuf-peer (name ROBOT1) (peer-id ?peer-id))
    (refbox-gamestate (team-color ?team-color))
    (protobuf-peer (name refbox-private) (peer-id ?refbox-peer-id))
    =>
    (bind ?mps "")
    (if (eq ?team-color CYAN) then
        (bind ?mps "C-BS")
    else
        (bind ?mps "M-BS")
    )
    (printout green "Discarding carrier on machine: " ?mps crlf)
    (if (eq ?task MoveMachineInput) then
        (executor-send-MoveMachine ?peer-id ?team-color 1 ?mps INPUT)
    )
    (if (eq ?task Retrieve) then
        (executor-send-Retrieve ?peer-id ?team-color 1 ?mps INPUT)
    )
    (if (eq ?task Instruct) then
        (printout green "Instructing MPS to dispense base" crlf)
        (refbox-instruct-dispense-bs ?mps ?team-color ?refbox-peer-id ?base-color INPUT)
    )
    (modify ?a (tasks ?tasks))
)

(defrule agent-actions-next-task-put-wp
    ?a <- (agent-action (id ?action-id) (name PUT-WP) (status ACTIVE) (args ?mps ?side) (tasks ?task $?tasks))
    (not (executor-task (status SENT)))
    (protobuf-peer (name ROBOT1) (peer-id ?peer-id))
    (refbox-gamestate (team-color ?team-color))
    (protobuf-peer (name refbox-private) (peer-id ?refbox-peer-id))
    =>
    (printout green "Putting wp on machine: " ?mps crlf)
    (if (eq ?task MoveMachineInput) then
        (executor-send-MoveMachine ?peer-id ?team-color 1 ?mps INPUT)
    )
    (if (eq ?task Deliver) then
        (executor-send-Deliver ?peer-id ?team-color 1 ?mps ?side)
    )
    (modify ?a (tasks ?tasks))
)

(defrule agent-actions-next-task-pay-ring
    ?a <- (agent-action (id ?action-id) (name PAY-RING) (status ACTIVE) (args ?mps) (tasks ?task $?tasks))
    (not (executor-task (status SENT)))
    (protobuf-peer (name ROBOT1) (peer-id ?peer-id))
    (refbox-gamestate (team-color ?team-color))
    (protobuf-peer (name refbox-private) (peer-id ?refbox-peer-id))
    =>
    (printout green "Paying for rings on machine: " ?mps crlf)
    (if (eq ?task MoveMachineInput) then
        (executor-send-MoveMachine ?peer-id ?team-color 1 ?mps INPUT)
    )
    (if (eq ?task Deliver) then
        (executor-send-Deliver ?peer-id ?team-color 1 ?mps SLIDE)
    )
    (modify ?a (tasks ?tasks))
)

(defrule agent-actions-next-task-pay-ring
    ?a <- (agent-action (id ?action-id) (name PAY-RING) (status ACTIVE) (args ?mps) (tasks ?task $?tasks))
    (not (executor-task (status SENT)))
    (protobuf-peer (name ROBOT1) (peer-id ?peer-id))
    (refbox-gamestate (team-color ?team-color))
    (protobuf-peer (name refbox-private) (peer-id ?refbox-peer-id))
    =>
    (printout green "Paying for rings on machine: " ?mps crlf)
    (if (eq ?task MoveMachineInput) then
        (executor-send-MoveMachine ?peer-id ?team-color 1 ?mps INPUT)
    )
    (if (eq ?task Deliver) then
        (executor-send-Deliver ?peer-id ?team-color 1 ?mps SLIDE)
    )
    (modify ?a (tasks ?tasks))
)

(defrule agent-actions-next-task-mount-ring
    ?a <- (agent-action (id ?action-id) (name MOUNT-RING) (status ACTIVE) (args ?mps ?ring-color) (tasks ?task $?tasks))
    (not (executor-task (status SENT)))
    (protobuf-peer (name ROBOT1) (peer-id ?peer-id))
    (refbox-gamestate (team-color ?team-color))
    (protobuf-peer (name refbox-private) (peer-id ?refbox-peer-id))
    =>
    (printout green "Mounting a ring on machine: " ?mps crlf)
    (if (eq ?task MoveMachineOutput) then
        (executor-send-MoveMachine ?peer-id ?team-color 1 ?mps OUTPUT)
    )
    (if (eq ?task Retrieve) then
        (executor-send-Retrieve ?peer-id ?team-color 1 ?mps OUTPUT)
    )
    (if (eq ?task Instruct) then
        (printout green "Instructing MPS to mount a ring" crlf)
        (refbox-instruct-mount-rs ?mps ?team-color ?refbox-peer-id ?ring-color)
    )
    (modify ?a (tasks ?tasks))
)

(defrule agent-actions-next-task-mount-cap
    ?a <- (agent-action (id ?action-id) (name MOUNT-CAP) (status ACTIVE) (args ?mps) (tasks ?task $?tasks))
    (not (executor-task (status SENT)))
    (protobuf-peer (name ROBOT1) (peer-id ?peer-id))
    (refbox-gamestate (team-color ?team-color))
    (protobuf-peer (name refbox-private) (peer-id ?refbox-peer-id))
    =>
    (printout green "Mounting a cap on machine: " ?mps crlf)
    (if (eq ?task MoveMachineOutput) then
        (executor-send-MoveMachine ?peer-id ?team-color 1 ?mps OUTPUT)
    )
    (if (eq ?task Retrieve) then
        (executor-send-Retrieve ?peer-id ?team-color 1 ?mps OUTPUT)
    )
    (if (eq ?task Instruct) then
        (printout green "Instructing MPS to mount a cap" crlf)
        (refbox-instruct-mount-cs ?mps ?team-color ?refbox-peer-id)
    )
    (modify ?a (tasks ?tasks))
)

(defrule agent-actions-next-task-deliver
    ?a <- (agent-action (id ?action-id) (name DELIVER) (status ACTIVE) (args ?order-id) (tasks ?task $?tasks))
    (not (executor-task (status SENT)))
    (protobuf-peer (name ROBOT1) (peer-id ?peer-id))
    (refbox-gamestate (team-color ?team-color))
    (protobuf-peer (name refbox-private) (peer-id ?refbox-peer-id))
    =>
    (bind ?mps "")
    (if (eq ?team-color CYAN) then
        (bind ?mps "C-DS")
    else
        (bind ?mps "M-DS")
    )
    (printout green "Delivering order " ?order-id crlf)
    (if (eq ?task MoveMachineInput) then
        (executor-send-MoveMachine ?peer-id ?team-color 1 ?mps INPUT)
    )
    (if (eq ?task Deliver) then
        (executor-send-Deliver ?peer-id ?team-color 1 ?mps INPUT)
    )
    (if (eq ?task Instruct) then
        (printout green "Instructing MPS for deliver" crlf)
        (refbox-instruct-deliver-ds ?mps ?team-color ?refbox-peer-id ?order-id)
    )
    (modify ?a (tasks ?tasks))
)