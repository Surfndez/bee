setup() {
  load 'test-helper.bash'
  _set_test_beerc
}

@test "is executable" {
  assert_file_executable "${PROJECT_ROOT}/src/bee"
}

@test "logs" {
  _source_bee
  run bee::log "test"
  assert_output "🐝 test"
}

@test "sources bee-run.bash" {
  _source_bee
  run bee::run echo "test"
  assert_output "test"
}
