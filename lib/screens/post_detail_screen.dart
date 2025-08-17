import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post.dart';
import '../models/user_model.dart';
import 'post_write_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final UserModel? currentUser;

  PostDetailScreen({required this.post, this.currentUser});

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late int _likes;

  @override
  void initState() {
    super.initState();
    _likes = widget.post.likes;
  }

  Future<void> _toggleLike() async {
    try {
      final newLikes = _likes + 1;

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .update({'likes': newLikes});

      setState(() {
        _likes = newLikes;
      });

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('좋아요!')),
      // );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _editPost() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostWriteScreen(
          currentUser: widget.currentUser!,
          editPost: widget.post,
        ),
      ),
    );
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('이벤트 삭제'),
        content: Text('정말로 이 이벤트를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.id)
            .delete();

        if (mounted) {
          Navigator.pop(context); // 상세보기 화면 닫기
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이벤트가 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일 '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('이벤트 상세'),
        backgroundColor: Colors.blue,
        actions: [
          // 관리자만 수정/삭제 버튼 표시
          if (widget.currentUser?.isAdmin == true) ...[
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: _editPost,
              tooltip: '수정',
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _deletePost,
              tooltip: '삭제',
            ),
          ],
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              widget.post.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),

            // 작성자 및 날짜
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    widget.post.author,
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    _formatDate(widget.post.createdAt),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // 내용
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.post.content,
                    style: TextStyle(fontSize: 16, height: 1.6),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),

            // 좋아요 버튼
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggleLike,
                icon: Icon(Icons.favorite, color: Colors.red),
                label: Text('좋아요 $_likes'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // 사용자 상태 표시
            if (widget.currentUser != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '${widget.currentUser!.name}님으로 로그인 중 (${widget.currentUser!.isAdmin ? '관리자' : '일반 사용자'})',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}