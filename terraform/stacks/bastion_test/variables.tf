variable "console_users" {
  type        = "map"
  description = "Map of user names (key) to their PGP key/keybase id (value) for users with console login."

  default = {
    user1 = "keybase:freisinger"
    user2 = "keybase:brainstorm"
  }
}

variable "service_users" {
  type        = "map"
  description = "Map of service user names (key) to their PGP key/keybase id (value)."

  # TODO: replace personal keybase ID with umccr account that multiple people have access to
  default = {
    service1 = "keybase:freisinger"
    service2 = "keybase:freisinger"
  }
}

variable "test_group_members" {
  type = "list"

  default = [
    "user1",
    "user2",
    "service1",
    "service2",
  ]
}
