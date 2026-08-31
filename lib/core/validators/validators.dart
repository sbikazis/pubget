abstract final class Validators {
  static bool isNonBlank(String? value) => value?.trim().isNotEmpty == true;
}
