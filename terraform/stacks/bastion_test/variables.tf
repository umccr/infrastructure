variable "console_users" {
  type        = "map"
  description = "Map of user names (key) to their PGP key/keybase id (value) for users with console login."

  default = {
    user1 = "keybase:freisinger"
    user2 = "keybase:brainstorm"

    user3 = "keybase:freisinger"
    user4 = "keybase:freisinger"
  }
}

variable "service_users" {
  type        = "map"
  description = "Map of service user names (key) to their PGP key/keybase id (value)."

  # TODO: replace personal keybase ID with umccr account that multiple people have access to
  default = {
    service1 = "keybase:freisinger"
    service2 = "keybase:freisinger"

    service3 = "keybase:freisinger"
  }
}

variable "group_memberships" {
  type = "map"

  default = {
    test_group_1 = ["user1", "user2"]

    # test_group_2 = ["service1", "service2"]

    test_group_2 = ["service1", "service2", "service3"]
    test_group_3 = ["user3", "user4", "service3"]
  }
}
