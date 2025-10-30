import 'package:flutter/material.dart';
import '../models/mbti_question.dart';
import '../models/mbti_test_session.dart';
import '../models/mbti_test_result.dart';
import '../data/mbti_questions.dart';
import '../services/mbti_test_service.dart';

class MbtiTestScreen extends StatefulWidget {
  final Function(MbtiTestResult)? onTestCompleted;

  const MbtiTestScreen({
    super.key,
    this.onTestCompleted,
  });

  @override
  State<MbtiTestScreen> createState() => _MbtiTestScreenState();
}

class _MbtiTestScreenState extends State<MbtiTestScreen>
    with TickerProviderStateMixin {
  late MbtiTestSession _session;
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _session = MbtiTestSession.createNew(MbtiQuestionsData.totalQuestions);
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _selectOption(int optionIndex) {
    if (_isLoading) return;

    final currentQuestion = MbtiQuestionsData.questions[_session.currentQuestionIndex];
    final answer = MbtiTestAnswer(
      questionNumber: currentQuestion.questionNumber,
      selectedOption: optionIndex,
      dimension: currentQuestion.dimension,
      answeredAt: DateTime.now(),
    );

    setState(() {
      _session = _session.addAnswer(answer);
    });

    _progressController.animateTo(_session.progressPercentage / 100);

    // 自动进入下一题或完成测试
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_session.isCompleted) {
        // 测试已完成，计算并保存结果
        _completeTest();
      } else if (_session.currentQuestionIndex < MbtiQuestionsData.totalQuestions - 1) {
        // 还有下一题
        _nextQuestion();
      } else {
        // 已到最后一题，完成测试
        _completeTest();
      }
    });
  }

  void _nextQuestion() {
    if (_session.currentQuestionIndex < MbtiQuestionsData.totalQuestions - 1) {
      setState(() {
        _session = MbtiTestSession(
          sessionId: _session.sessionId,
          startTime: _session.startTime,
          endTime: _session.endTime,
          answers: _session.answers,
          result: _session.result,
          isCompleted: _session.isCompleted,
          currentQuestionIndex: _session.currentQuestionIndex + 1,
          totalQuestions: _session.totalQuestions,
        );
      });
      _fadeController.reset();
      _fadeController.forward();
    }
  }

  void _previousQuestion() {
    if (_session.currentQuestionIndex > 0) {
      setState(() {
        _session = MbtiTestSession(
          sessionId: _session.sessionId,
          startTime: _session.startTime,
          endTime: _session.endTime,
          answers: _session.answers,
          result: _session.result,
          isCompleted: _session.isCompleted,
          currentQuestionIndex: _session.currentQuestionIndex - 1,
          totalQuestions: _session.totalQuestions,
        );
      });
      _fadeController.reset();
      _fadeController.forward();
    }
  }

  Future<void> _completeTest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await MbtiTestService.calculateResult(_session.answers);
      final completedSession = _session.completeWithResult(result);
      
      // 保存测试结果到后端
      await MbtiTestService.saveTestResult(result);

      setState(() {
        _session = completedSession;
        _isLoading = false;
      });

      // 通知父组件测试完成
      if (widget.onTestCompleted != null) {
        widget.onTestCompleted!(result);
      }

      // 显示结果页面
      _showResultDialog(result);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('测试完成失败: $e');
    }
  }

  void _showResultDialog(MbtiTestResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('测试完成！'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '你的MBTI类型是: ${result.mbtiType}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              SizedBox(height: 16),
              Text(
                result.primaryTrait,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Text(
                result.description,
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                '测试用时: ${_session.formattedDuration}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // 返回AI地图页面
            },
            child: Text('返回AI地图'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在分析你的性格类型...'),
            ],
          ),
        ),
      );
    }

    if (_session.isCompleted && _session.result != null) {
      return _buildResultView();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('MBTI性格测试'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('退出测试'),
                  content: Text('确定要退出测试吗？进度将不会保存。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: Text('确定'),
                    ),
                  ],
                ),
              );
            },
            child: Text(
              '退出',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _session.isCompleted && _session.result != null
            ? _buildResultView()
            : Column(
                children: [
                  _buildProgressSection(),
                  Expanded(
                    child: _buildQuestionSection(),
                  ),
                  _buildNavigationSection(),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '第 ${_session.currentQuestionIndex + 1} 题',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '共 ${_session.totalQuestions} 题',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressController.value,
                backgroundColor: Colors.white30,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
              );
            },
          ),
          SizedBox(height: 8),
          Text(
            '${(_session.progressPercentage).toStringAsFixed(1)}%',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSection() {
    // 检查索引是否有效
    if (_session.currentQuestionIndex < 0 || 
        _session.currentQuestionIndex >= MbtiQuestionsData.questions.length) {
      return Center(
        child: Text(
          '题目索引无效',
          style: TextStyle(fontSize: 16, color: Colors.red),
        ),
      );
    }
    
    final currentQuestion = MbtiQuestionsData.questions[_session.currentQuestionIndex];
    final previousAnswer = _session.getAnswerForQuestion(currentQuestion.questionNumber);

    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentQuestion.question,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: currentQuestion.options.length,
              itemBuilder: (context, index) {
                final isSelected = previousAnswer?.selectedOption == index;
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectOption(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue[50] : Colors.grey[50],
                          border: Border.all(
                            color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Colors.blue[500] : Colors.grey[300],
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                currentQuestion.options[index],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isSelected ? Colors.blue[800] : Colors.grey[800],
                                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: _session.currentQuestionIndex > 0 ? _previousQuestion : null,
            icon: Icon(Icons.arrow_back),
            label: Text('上一题'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          Text(
            '${_session.answeredQuestionsCount}/${_session.totalQuestions}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _session.currentQuestionIndex < MbtiQuestionsData.totalQuestions - 1
                ? _nextQuestion
                : null,
            icon: Icon(Icons.arrow_forward),
            label: Text('下一题'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final result = _session.result!;
    return Scaffold(
      appBar: AppBar(
        title: Text('测试结果'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '你的MBTI类型',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      result.mbtiType,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      result.primaryTrait,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '性格描述',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      result.description,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '测试详情',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('测试用时:'),
                        Text(_session.formattedDuration),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('测试日期:'),
                        Text(result.testDate.toString().split(' ')[0]),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('置信度:'),
                        Text('${(result.confidenceScore * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.onTestCompleted != null) {
                    widget.onTestCompleted!(result);
                  }
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '开始AI性格分析',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
