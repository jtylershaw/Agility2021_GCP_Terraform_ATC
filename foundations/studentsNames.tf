variable "listOfNames" {
  type = list(string)
}

resource "google_project_iam_member" "editors" {
  for_each = toset(var.listOfNames)
    project = var.project_id
    role    = "roles/editor"
    member  = format("user:%s",each.value)
}

resource "google_project_iam_member" "iamAdmin" {
  for_each = toset(var.listOfNames)
    project = var.project_id
    role    = "roles/iam.roleAdmin"
    member  = format("user:%s",each.value)
}

output "studentIDemail" {
  value = [
    var.listOfNames[index],
    description "Student "
  ]
}
