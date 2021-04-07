variable "listOfNames" {
  type = list(string)
}

resource "google_project_iam_member" "project" {
  for_each = toset(var.listOfNames)
    project = var.project_id
    role    = "roles/editor"
    member  = format("user:%s",each.value)
}
