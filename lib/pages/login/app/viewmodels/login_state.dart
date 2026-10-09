class LoginPageState {
  final String? emailId;
  final String? password;
  final String? dataRegion;
  final String errorMessage;
  final bool isLoading;

  LoginPageState({
    this.emailId,
    this.password,
    this.dataRegion,
    this.errorMessage = '',
    this.isLoading = false,
  });

  LoginPageState copyWith({
    String? emailId,
    String? password,
    String? dataRegion,
    String? errorMessage,
    bool? isLoading,
  }) {
    return LoginPageState(
      emailId: emailId ?? this.emailId,
      password: password ?? this.password,
      dataRegion: dataRegion ?? this.dataRegion,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  String toString() {
    return 'LoginPageState(emailId: $emailId, password: $password, dataRegion: $dataRegion, errorMessage:$errorMessage,isLoading: $isLoading)';
  }

  Map<String, dynamic> toJson() {
    return {
      'emailId': emailId,
      'password': password,
      'dataRegion': dataRegion,
      'errorMessage': errorMessage,
      'isLoading': isLoading,
    };
  }

  factory LoginPageState.fromJson(Map<String, dynamic> json) {
    return LoginPageState(
      emailId: json['emailId'],
      password: json['password'],
      errorMessage: json['errorMessage'] ?? '',
      dataRegion: json['dataRegion'],
      isLoading: json['isLoading'],
    );
  }
}
