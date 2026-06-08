import 'package:flutter/material.dart';

import '../../main.dart';
import '../../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final server = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    server.text = await widget.state.syncEngine.serverUrl;
    email.text = await widget.state.syncEngine.email ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    server.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        blueHeader(
          title: '설정',
          subtitle: widget.state.syncMessage,
          trailing: const Icon(Icons.cloud_sync, color: Colors.white, size: 34),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('접근성', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('본문 폰트 크기 ${(16 * widget.state.fontScale).round()}sp 이상'),
                      Slider(
                        value: widget.state.fontScale,
                        min: 1,
                        max: 1.35,
                        divisions: 7,
                        label: '${(widget.state.fontScale * 100).round()}%',
                        onChanged: widget.state.setFontScale,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('동기화 서버', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      TextField(controller: server, decoration: const InputDecoration(labelText: '서버 URL')),
                      const SizedBox(height: 12),
                      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: '이메일')),
                      const SizedBox(height: 12),
                      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호')),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(child: OutlinedButton(onPressed: () => _auth(register: true), child: const Text('회원가입'))),
                          const SizedBox(width: 12),
                          Expanded(child: FilledButton(onPressed: () => _auth(register: false), child: const Text('로그인'))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: widget.state.syncNow,
                        icon: const Icon(Icons.sync),
                        label: const SizedBox(width: double.infinity, child: Center(child: Text('지금 동기화'))),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('오프라인 우선 구조', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '모든 변경은 먼저 로컬 SQLite에 저장됩니다. 로그인 후 동기화하면 updated_at, is_deleted, device_id를 기준으로 서버와 변경분을 교환하고 마지막 수정 우선 규칙으로 충돌을 해결합니다.',
                    style: TextStyle(color: AppColors.text, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _auth({required bool register}) async {
    await widget.state.syncEngine.setServerUrl(server.text);
    try {
      if (register) {
        await widget.state.syncEngine.register(email.text.trim(), password.text);
      } else {
        await widget.state.syncEngine.login(email.text.trim(), password.text);
      }
      await widget.state.syncNow();
      if (mounted) _message(register ? '회원가입 및 동기화 완료' : '로그인 및 동기화 완료');
    } catch (error) {
      if (mounted) _message('인증 실패: $error');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
