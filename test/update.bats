setup() {
  load "test-helper.bash"
}

@test "shows help when args" {
  run bee update test
  assert_bee_help
}