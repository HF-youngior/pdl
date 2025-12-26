// lib/screens/personal_log_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:testflutterproject/models/personal_log.dart';
import 'package:testflutterproject/models/log_task_update.dart';
import 'package:testflutterproject/models/task.dart';
import 'package:testflutterproject/services/api_service.dart';
import 'package:testflutterproject/services/task_service.dart'; // 您的仓库中已存在
import 'package:testflutterproject/services/geocoding_service.dart';
import 'package:testflutterproject/utils/coordinate_converter.dart';

class PersonalLogEditScreen extends StatefulWidget {
  final String userId;
  final PersonalLog? logToEdit;


  const PersonalLogEditScreen({Key? key, required this.userId, this.logToEdit}) : super(key: key);

  bool get isEditing => logToEdit != null;


  @override
  _PersonalLogEditScreenState createState() => _PersonalLogEditScreenState();
}

class _PersonalLogEditScreenState extends State<PersonalLogEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final TaskService _taskService = TaskService(); 

  // 表单状态
  late DateTime _selectedDate;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String? _selectedCategory;
  List<LogTaskUpdate> _currentTaskUpdates = [];
  List<Task> _availableTasks = [];
  List<String> _currentKeywords = [];

  bool _isLoadingTasks = true;
  bool _isSaving = false;
  
  // 图片相关
  final List<File> _selectedImages = [];
  final List<String> _persistedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  // 地理位置
  String? _locationName;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  final Map<String, String> _taskStatuses = {
    'pending': '待处理',
    'in_progress': '进行中',
    'completed': '已完成',
    'cancelled': '已取消',
  };



  // 匹配您后端 personal_logs 表的定义
  final List<String> _logCategories = ['工作总结', '工作进展', '会议记录', '工作记录', '学习笔记', '其他'];
  // Remove all quadrant state/fields/UI from form and code
  // Ensure keywords, content, and category are correctly passed



  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();

    if (widget.isEditing) {
      _selectedDate = DateTime.parse(widget.logToEdit!.createdAt??'');
      _titleController.text = widget.logToEdit!.title??'';
      _contentController.text = widget.logToEdit!.content ?? '';
      _selectedCategory = widget.logToEdit?.category ?? '';
      _currentTaskUpdates = widget.logToEdit!.taskUpdates.map((upd) => upd.copyWith()).toList();
      _currentKeywords = List.of(widget.logToEdit!.keywords);
      _persistedImages.addAll(widget.logToEdit!.images);
      _locationName = widget.logToEdit!.locationAddress ?? widget.logToEdit!.locationName;
      _latitude = widget.logToEdit!.latitude;
      _longitude = widget.logToEdit!.longitude;
    } else {
      // 修复时间问题：使用本地时间，确保日期正确
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
      _currentKeywords = [];
    }

    _loadAvailableTasks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTasks() async {
    setState(() => _isLoadingTasks = true);
    try {
      // 假设 TaskService.getTasks(userId) 返回 Task 列表
      _availableTasks = (await TaskService.getTasks()).where((task) => task.assigneeId == widget.userId).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载任务列表失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showAddTaskDialog() {
    if (_isLoadingTasks) return;

    final taskIdsAlreadyAdded = _currentTaskUpdates.map((upd) => upd.taskId).toSet();
    final tasksToShow = _availableTasks.where((task) => !taskIdsAlreadyAdded.contains(task.id)).toList();

    if (tasksToShow.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('所有可用任务均已关联')),
      );
      return;
    }

    Task? selectedTask; 
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择要关联的任务'),
          content: DropdownButtonFormField<Task>(
            hint: Text('请选择任务'),
            items: tasksToShow.map((Task task) {
              return DropdownMenuItem<Task>(
                value: task,
                child: Text(task.title, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (Task? newValue) {
              selectedTask = newValue;
            },
            isExpanded: true,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('添加'),
              onPressed: () {
                if (selectedTask != null) {
                  setState(() {
                    _currentTaskUpdates.add(LogTaskUpdate(
                      taskId: selectedTask!.id,
                      taskName: selectedTask!.title,
                      progress_percentage: selectedTask!.progressPercentage,
                      task_status: 'in_progress', // 默认状态始终为进行中
                    ));
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _removeTaskUpdate(int index) {
    setState(() {
      _currentTaskUpdates.removeAt(index);
    });
  }

  void _updateTaskProgress(int index, int? value) {
    setState(() {
      _currentTaskUpdates[index] = _currentTaskUpdates[index].copyWith(
        progress_percentage: value,
        task_status: (value == 100 && _currentTaskUpdates[index].task_status != 'completed') 
                      ? 'completed' 
                      : _currentTaskUpdates[index].task_status,
      );
    });
  }

  void _updateTaskStatus(int index, String? value) {
    setState(() {
      _currentTaskUpdates[index] = _currentTaskUpdates[index].copyWith(
        task_status: value,
        progress_percentage: (value == 'completed' && _currentTaskUpdates[index].progress_percentage != 100) 
                            ? 100 
                            : _currentTaskUpdates[index].progress_percentage,
        setStatusToNull: value == null,
      );
    });
  }

  // 选择图片
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e')),
      );
    }
  }

  // 删除图片
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removePersistedImage(int index) {
    setState(() {
      _persistedImages.removeAt(index);
    });
  }

  Widget _buildPersistedImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildBrokenImage(),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
      );
    }
    return _buildBrokenImage();
  }

  Widget _buildBrokenImage() {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('位置权限被拒绝')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置权限被永久拒绝，请到系统设置开启')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 将WGS84坐标转换为GCJ-02坐标（高德地图使用的坐标系）
      final converted = CoordinateConverter.wgs84ToGcj02(
        position.latitude,
        position.longitude,
      );
      final convertedLat = converted['latitude']!;
      final convertedLon = converted['longitude']!;

      // 先设置转换后的坐标
      setState(() {
        _latitude = convertedLat;
        _longitude = convertedLon;
        _locationName =
            '${convertedLat.toStringAsFixed(6)}, ${convertedLon.toStringAsFixed(6)}';
      });

      // 尝试将坐标转换为地址（使用转换后的GCJ-02坐标）
      try {
        final address = await GeocodingService.reverseGeocodeCached(
          convertedLat,
          convertedLon,
        );
        if (address != null && mounted) {
          setState(() {
            _locationName = address;
            _isLoadingLocation = false;
          });
        } else {
          setState(() {
            _isLoadingLocation = false;
          });
        }
      } catch (e) {
        // 如果逆地理编码失败，保持使用坐标
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取位置失败: $e')),
      );
    }
  }

  void _clearLocation() {
    setState(() {
      _locationName = null;
      _latitude = null;
      _longitude = null;
    });
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      // 先上传新选择的图片
      List<String> uploadedImageUrls = [];
      if (_selectedImages.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在上传图片...'), duration: Duration(seconds: 1)),
        );
        
        final urls = await ApiService.uploadImages(_selectedImages);
        if (urls.length != _selectedImages.length) {
          throw Exception('部分图片上传失败，请重试');
        }
        uploadedImageUrls = urls;
      }

      // 合并已存在的图片URL和新上传的图片URL
      final allImageUrls = [
        ..._persistedImages, // 这些已经是URL了
        ...uploadedImageUrls, // 新上传的URL
      ];

      // 匹配后端 API 的 {log, linkages} 结构
      final logPayload = {
        'log_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'title': _titleController.text,
        'content': _contentController.text,
        'category': _selectedCategory,
        'keywords': _currentKeywords,
        'is_completed': widget.isEditing ? widget.logToEdit!.isCompleted : false,
        'images': allImageUrls,
      };

      if (_locationName != null) {
        logPayload['location'] = {
          'name': _locationName,
          'latitude': _latitude,
          'longitude': _longitude,
        };
      }

      final logData = {
        'log': logPayload,
        // 确保 linkages 发送的是 snake_case
        'linkages': _currentTaskUpdates.map((update) => update.toJson()).toList(),
      };

      if (widget.isEditing) {
        await ApiService.updatePersonalLog(widget.logToEdit!.id, logData);
      } else {
        await ApiService.createPersonalLog(logData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('日志已保存'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true); 

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑日志' : '创建日志'),
        actions: [
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveLog,
              tooltip: '保存日志',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( 
            children: [
              _buildBasicInfoCard(),
              SizedBox(height: 16),
              _buildTaskUpdatesCard(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('基本信息', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("日期: "+DateFormat('yyyy-MM-dd').format(_selectedDate)),
              trailing: Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
              onTap: () => _selectDate(context),
            ),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '日志标题',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty) ? '请输入日志标题' : null,
            ),
            _buildKeywordInput(),
            SizedBox(height: 12),
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: '日志内容',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            SizedBox(height: 16),
            // 图片上传
            Text('图片', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library),
                    label: Text('从相册选择'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: Icon(Icons.camera_alt),
                    label: Text('拍照'),
                  ),
                ),
              ],
            ),
            if (_selectedImages.isNotEmpty) ...[
              SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            if (_persistedImages.isNotEmpty) ...[
              SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _persistedImages.length,
                  itemBuilder: (context, index) {
                    final path = _persistedImages[index];
                    return Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildPersistedImage(path),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removePersistedImage(index),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: 16),
            Text('地理位置', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            if (_locationName != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationName!,
                        style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                      ),
                    ),
                    IconButton(
                      onPressed: _clearLocation,
                      icon: Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                icon: _isLoadingLocation
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.location_on),
                label: Text(_isLoadingLocation ? '定位中…' : '获取当前位置'),
              ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: Text('选择分类'),
              items: _logCategories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
              validator: (value) => value == null ? '请选择分类' : null,
              decoration: InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordInput() {
    final _keywordInputCtrl = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('关键词', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _currentKeywords
              .map((k) => Chip(
                    label: Text(k),
                    onDeleted: () {
                      setState(() => _currentKeywords.remove(k));
                    },
                  ))
              .toList(),
        ),
        TextField(
          controller: _keywordInputCtrl,
          decoration: InputDecoration(
            hintText: '输入关键词后按回车或逗号添加',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          ),
          onSubmitted: (val) {
            final v = val.trim();
            if (v.isNotEmpty && !_currentKeywords.contains(v)) {
              setState(() => _currentKeywords.add(v));
            }
            _keywordInputCtrl.clear();
          },
          onChanged: (v) {
            if (v.endsWith(',') || v.endsWith('，')) {
              final kw = v.substring(0, v.length - 1).trim();
              if (kw.isNotEmpty && !_currentKeywords.contains(kw)) {
                setState(() => _currentKeywords.add(kw));
              }
              _keywordInputCtrl.clear();
            }
          },
        ),
      ],
    );
  }

  Widget _buildTaskUpdatesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('关联任务', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: Theme.of(context).primaryColor, size: 30),
                  onPressed: _isLoadingTasks ? null : _showAddTaskDialog,
                  tooltip: '添加任务关联',
                ),
              ],
            ),
            Divider(height: 24),
            if (_isLoadingTasks)
              Center(child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ))
            else if (_currentTaskUpdates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text('未关联任何任务', style: TextStyle(color: Colors.grey[600])),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _currentTaskUpdates.length,
                itemBuilder: (context, index) {
                  final taskUpdate = _currentTaskUpdates[index];
                  final double sliderValue = (taskUpdate.progress_percentage ?? 0).toDouble();

                  return Container(
                     margin: EdgeInsets.symmetric(vertical: 8),
                     decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey[300]!),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Padding(
                       padding: const EdgeInsets.all(12.0),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Expanded(
                                 child: Text(
                                   taskUpdate.taskName ?? '任务 #${taskUpdate.taskId}',
                                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ),
                               IconButton(
                                 icon: Icon(Icons.remove_circle, color: Colors.red[400]),
                                 onPressed: () => _removeTaskUpdate(index),
                                 tooltip: '移除此任务关联',
                               ),
                             ],
                           ),
                           SizedBox(height: 8),
                           Text('进度更新: ${taskUpdate.progress_percentage ?? '未设置'}%'),
                           Slider(
                             value: sliderValue,
                             min: 0,
                             max: 100,
                             divisions: 10,
                             label: '${sliderValue.round()}%',
                             onChanged: (double value) {
                               _updateTaskProgress(index, value.round());
                             },
                           ),
                           DropdownButtonFormField<String>(
                             value: taskUpdate.task_status,
                             hint: Text('状态更新 (可选)'),
                             items: _taskStatuses.entries.map((entry) { // 1. 使用 .entries 获取可迭代的 MapEntry
                               return DropdownMenuItem<String>(
                                 value: entry.key, // 2. Map 的键是英文状态码 ('pending', 'completed')
                                 child: Text(entry.value), // 3. Map 的值是中文文本 ('待处理', '已完成')
                               );
                             }).toList(), // 4. 调用 toList() 将 Iterable 转换为 List
                             onChanged: (String? newValue) => _updateTaskStatus(index, newValue),
                             decoration: InputDecoration(
                               border: OutlineInputBorder(),
                               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                               suffixIcon: taskUpdate.task_status != null
                                 ? IconButton(
                                     icon: Icon(Icons.clear, size: 18),
                                     onPressed: () => _updateTaskStatus(index, null),
                                   )
                                 : null,
                             ),
                           ),
                         ],
                       ),
                     ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
