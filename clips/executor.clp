(deftemplate executor-task-sequence
    (slot seq (type INTEGER))
)

(deftemplate executor-task
    (slot name (type SYMBOL))
    (slot robot (type INTEGER))
    (slot seq (type INTEGER))
    (slot peer (type INTEGER))
    (slot status (type SYMBOL)) ; SENT, SUCCEEDED, FAILED, CANCELLED
    (slot error (type STRING)) ; error message if any
)

(deffacts executor-task-sequence
    (executor-task-sequence (seq 0))
)

;-------------------------

(deffunction executor-get-task-sequence()
    (bind ?seq 0)
    (do-for-all-facts ((?f executor-task-sequence)) TRUE
        (bind ?seq ?f:seq)
        (retract ?f)
        (assert (executor-task-sequence (seq (+ 1 ?seq))))
    )
    (return ?seq)
)

(deffunction executor-send-MoveMachine (?peer-id ?team-color ?robot-number ?machine ?side)
    (bind ?task-msg (pb-create "llsf_msgs.AgentTask"))
    (bind ?task-info (pb-create "llsf_msgs.Move"))
    (pb-set-field ?task-msg "team_color" ?team-color)
    (pb-set-field ?task-msg "robot_id" ?robot-number)
    (bind ?task-id (executor-get-task-sequence))
    (pb-set-field ?task-msg "task_id" ?task-id)

    (pb-set-field ?task-info "waypoint" ?machine)
    (pb-set-field ?task-info "machine_point" ?side)

    (pb-set-field ?task-msg "move" ?task-info)

    (pb-send ?peer-id ?task-msg)
    (pb-destroy ?task-msg)
    (assert (executor-task (name Move) (robot ?robot-number) (seq ?task-id) (peer ?peer-id) (status SENT) (error "")))
    (printout green "Sent task (Move) with id " ?task-id " to robot " ?robot-number "!" crlf)
)

(deffunction executor-send-Move (?peer-id ?team-color ?robot-number ?zone)
    (bind ?task-msg (pb-create "llsf_msgs.AgentTask"))
    (bind ?task-info (pb-create "llsf_msgs.Move"))
    (pb-set-field ?task-msg "team_color" ?team-color)
    (pb-set-field ?task-msg "robot_id" ?robot-number)
    (bind ?task-id (executor-get-task-sequence))
    (pb-set-field ?task-msg "task_id" ?task-id)

    (pb-set-field ?task-info "waypoint" ?zone)

    (pb-set-field ?task-msg "move" ?task-info)

    (pb-send ?peer-id ?task-msg)
    (pb-destroy ?task-msg)
    (assert (executor-task (name Move) (robot ?robot-number) (seq ?task-id) (peer ?peer-id) (status SENT) (error "")))
    (printout green "Sent task (Move) with id " ?task-id " to robot " ?robot-number "!" crlf)
)

(deffunction executor-send-Retrieve (?peer-id ?team-color ?robot-number ?machine ?side)
    (bind ?task-msg (pb-create "llsf_msgs.AgentTask"))
    (bind ?task-info (pb-create "llsf_msgs.Retrieve"))
    (pb-set-field ?task-msg "team_color" ?team-color)
    (pb-set-field ?task-msg "robot_id" ?robot-number)
    (bind ?task-id (executor-get-task-sequence))
    (pb-set-field ?task-msg "task_id" ?task-id)

    (pb-set-field ?task-info "machine_id" ?machine)
    (pb-set-field ?task-info "machine_point" ?side)

    (pb-set-field ?task-msg "retrieve" ?task-info)

    (pb-send ?peer-id ?task-msg)
    (pb-destroy ?task-msg)
    (assert (executor-task (name Retrieve) (robot ?robot-number) (seq ?task-id) (peer ?peer-id) (status SENT) (error "")))
    (printout green "Sent task (Retrieve) with id " ?task-id " to robot " ?robot-number "!" crlf)
)

(deffunction executor-send-Deliver (?peer-id ?team-color ?robot-number ?machine ?side)
    (bind ?task-msg (pb-create "llsf_msgs.AgentTask"))
    (bind ?task-info (pb-create "llsf_msgs.Deliver"))
    (pb-set-field ?task-msg "team_color" ?team-color)
    (pb-set-field ?task-msg "robot_id" ?robot-number)
    (bind ?task-id (executor-get-task-sequence))
    (pb-set-field ?task-msg "task_id" ?task-id)

    (pb-set-field ?task-info "machine_id" ?machine)
    (pb-set-field ?task-info "machine_point" ?side)

    (pb-set-field ?task-msg "deliver" ?task-info)

    (pb-send ?peer-id ?task-msg)
    (pb-destroy ?task-msg)
    (assert (executor-task (name Deliver) (robot ?robot-number) (seq ?task-id) (peer ?peer-id) (status SENT) (error "")))
    (printout green "Sent task (Deliver) with id " ?task-id " to robot " ?robot-number "!" crlf)
)

(deffunction executor-send-BufferStation (?peer-id ?team-color ?robot-number ?machine ?shelf-number)
    (bind ?task-msg (pb-create "llsf_msgs.AgentTask"))
    (bind ?task-info (pb-create "llsf_msgs.BufferStation"))
    (pb-set-field ?task-msg "team_color" ?team-color)
    (pb-set-field ?task-msg "robot_id" ?robot-number)
    (bind ?task-id (executor-get-task-sequence))
    (pb-set-field ?task-msg "task_id" ?task-id)

    (pb-set-field ?task-info "machine_id" ?machine)
    (pb-set-field ?task-info "shelf_number" ?shelf-number)

    (pb-set-field ?task-msg "buffer" ?task-info)

    (pb-send ?peer-id ?task-msg)
    (pb-destroy ?task-msg)
    (assert (executor-task (name BufferStation) (robot ?robot-number) (seq ?task-id) (peer ?peer-id) (status SENT) (error "")))
    (printout green "Sent task (BufferStation) with id " ?task-id " to robot " ?robot-number "!" crlf)
)

(deffunction executor-send-ExploreWaypoint (?peer-id ?team-color ?robot-number ?machine ?side ?waypoint)
    (bind ?task-msg (pb-create "llsf_msgs.AgentTask"))
    (bind ?task-info (pb-create "llsf_msgs.ExploreWaypoint"))
    (pb-set-field ?task-msg "team_color" ?team-color)
    (pb-set-field ?task-msg "robot_id" ?robot-number)
    (bind ?task-id (executor-get-task-sequence))
    (pb-set-field ?task-msg "task_id" ?task-id)

    (pb-set-field ?task-info "machine_id" ?machine)
    (pb-set-field ?task-info "machine_point" ?side)
    (pb-set-field ?task-info "waypoint" ?waypoint)

    (pb-set-field ?task-msg "explore_machine" ?task-info)

    (pb-send ?peer-id ?task-msg)
    (pb-destroy ?task-msg)
    (assert (executor-task (name ExploreWaypoint) (robot ?robot-number) (seq ?task-id) (peer ?peer-id) (status SENT) (error "")))
    (printout green "Sent task (ExploreWaypoint) with id " ?task-id " to robot " ?robot-number "!" crlf)
)

;------------------------

(defrule executor-initialise
    (configured)
    (not (executor-initialised))
    (confval (path "/simulator/host") (value ?peer-address))
    (confval (path "/simulator/robot-recv-ports") (is-list TRUE) (list-value $?recv-ports))
    (confval (path "/simulator/robot-send-ports") (is-list TRUE) (list-value $?send-ports))
    =>
    (loop-for-count (?i (length$ ?recv-ports)) do
        (bind ?peer-id (pb-peer-create-local ?peer-address (string-to-field (nth$ ?i ?send-ports)) (string-to-field (nth$ ?i ?recv-ports))))
        (assert (protobuf-peer (name (sym-cat "ROBOT" ?i)) (peer-id ?peer-id)))
    )
    (assert (executor-initialised))
)

;------------------

(defrule executor-recv-feedback
    ?pf <- (protobuf-msg (type "llsf_msgs.AgentTask") (ptr ?task-msg))
    ?et <- (executor-task (robot ?robot-number) (name ?task-name) (seq ?task-id) (peer ?peer-id) (status ?status))
    (refbox-gamestate (team-color ?team-color))
    (test
        (and
            (eq (pb-field-value ?task-msg "task_id") ?task-id)
            (eq (pb-field-value ?task-msg "robot_id") ?robot-number)
            (eq (pb-field-value ?task-msg "team_color") ?team-color)
        )
    )
    =>
    (if (pb-has-field ?task-msg "cancelled") then
        (if (and (pb-field-value ?task-msg "cancelled") (not (eq ?status CANCELLED))) then
            (modify ?et (status CANCELLED) (error "Task cancelled"))
            (printout error "Executor (" ?task-name ") with id " ?task-id " Cancelled!" crlf)
        )
    )

    (if (pb-has-field ?task-msg "successful") then
        (bind ?successful (pb-field-value ?task-msg "successful"))
        (if ?successful then
            (modify ?et (status SUCCESSFUL))
            (printout green "Executor (" ?task-name ") with id " ?task-id " finished successfully!" crlf)
        else
            (bind ?error-code (pb-field-value ?task-msg "error_code"))

            (if (eq ?error-code 0) then
                (modify ?et (status SUCCESSFUL))
            else if (eq ?error-code 1) then
                (modify ?et (status FAILED) (error "Unknown error occurred"))
            else if (eq ?error-code 101) then
                (modify ?et (status FAILED) (error "Wrong team"))
            else if (eq ?error-code 102) then
                (modify ?et (status FAILED) (error "Wrong robot"))
            else if (eq ?error-code 103) then
                (modify ?et (status FAILED) (error "Invalid target"))
            else if (eq ?error-code 104) then
                (modify ?et (status FAILED) (error "Task not supported"))
            else if (eq ?error-code 105) then
                (modify ?et (status FAILED) (error "Not at position"))
            else if (eq ?error-code 201) then
                (modify ?et (status FAILED) (error "Unable to move to target"))
            else if (eq ?error-code 202) then
                (modify ?et (status FAILED) (error "No workpiece found"))
            else if (eq ?error-code 203) then
                (modify ?et (status FAILED) (error "MPS not found"))
            else if (eq ?error-code 204) then
                (modify ?et (status FAILED) (error "Workpiece sensor disagreement"))
            else if (eq ?error-code 205) then
                (modify ?et (status FAILED) (error "Aborted due to unexpected collision"))
            else if (eq ?error-code 206) then
                (modify ?et (status FAILED) (error "Grasping failed"))
            else if (eq ?error-code 207) then
                (modify ?et (status FAILED) (error "Workpiece already in gripper"))
            else if (eq ?error-code 208) then
                (modify ?et (status FAILED) (error "No workpiece in gripper"))
            else if (eq ?error-code 209) then
                (modify ?et (status FAILED) (error "Machine point occupied"))
            else if (eq ?error-code 220) then
                (modify ?et (status FAILED) (error "Internal error"))
            else if (eq ?error-code 300) then
                (modify ?et (status FAILED) (error "No path found"))
            )

            (printout error "Executor (" ?task-name ") with id " ?task-id " got aborted with error " (fact-slot-value ?et error) crlf)
        )
    )

    (retract ?pf)
)

(defrule executor-recv-handle-unknown-task-msg
  ?pf <- (protobuf-msg (type "llsf_msgs.AgentTask") (ptr ?task-msg))
  =>
  (retract ?pf)
)
