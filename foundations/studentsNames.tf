variable "listOfNames" {
  type = list(string)
}

variable "expiration"

resource "google_project_iam_member" "editors" {
  for_each = toset(var.listOfNames)
    project = var.project_id
    role    = "roles/editor"
    member  = format("user:%s",each.value)

  condition {
    title       = "studentEditorExpiration"
    expression  = "request.time < timestamp(\"2021-16-04T00:00:00Z\")"
  }
}

resource "google_project_iam_member" "iamAdmin" {
  for_each = toset(var.listOfNames)
    project = var.project_id
    role    = "roles/iam.roleAdmin"
    member  = format("user:%s",each.value)

  condition {
    title       = "studentIAMexpiration"
    expression  = "request.time < timestamp(\"2021-16-04T00:00:00Z\")"
  }
}

output "studentIDemail" {
  for_each = toset(var.listOfNames)
    value = format("user:%s student:%s",each.value, index(listOfNames, value))
}
