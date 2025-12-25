import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/user.dart';
import '../models/task.dart';
import '../models/log.dart';
import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../utils/coordinate_converter.dart';

class LogEditScreen extends StatefulWidget {
  final User user;
  final DateTime? initialDate;

  const LogEditScreen({
    super.key,
    required this.user,
    this.initialDate,
  });

  @override
  State<LogEditScreen> createState() => _LogEditScreenState();
}

class _LogEditScreenState extends State<LogEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actionController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedCategory = 'work';
  final String _selectedQuadrant = 'important_not_urgent';
  String? _selectedTaskId;
  
  late DateTime _selectedDate;
  String _selectedWeather = 'sunny';
  final List<String> _keywords = [];
  final TextEditingController _keywordInputController = TextEditingController();
  final Map<String, _AssociatedTaskEdit> _selectedTaskEdits = {};
  
  List<Task> _tasks = [];
  bool _isLoadingTasks = true;
  bool _isSaving = false;
  
  // 图片相关
  final List<File> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  
  // 地理位置相关
  String? _locationName;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    // 修复时间问题：使用本地时间，确保日期正确
    final now = DateTime.now();
    _selectedDate = widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _loadTasks();
  }

  @override
  void dispose() {
    _actionController.dispose();
    _descriptionController.dispose();
    _keywordInputController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await ApiService.getTasks();
      setState(() {
        _tasks = tasks;
        _isLoadingTasks = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTasks = false;
      });
    }
  }

  Future<void> _saveLog() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_actionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写日志标题')),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写日志内容')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 上传图片并获取可访问的URL
      List<String> uploadedImageUrls = [];
      if (_selectedImages.isNotEmpty) {
        uploadedImageUrls = await ApiService.uploadImages(_selectedImages);
      }

      final associatedTasks = _selectedTaskEdits.entries.map((entry) {
        return {
          'task_id': entry.key,
          'feeling': entry.value.feeling,
          'note': entry.value.note,
        };
      }).toList();

      // 构建metadata对象，包含扩展信息
      final metadata = {
        'log_date': '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        'weather': _selectedWeather,
        'keywords': _keywords.join(','),
        'associated_tasks': associatedTasks,
        'images': uploadedImageUrls,
        'location': _locationName != null ? {
          'name': _locationName,
          'latitude': _latitude,
          'longitude': _longitude,
        } : null,
      };

      // 创建Log对象，使用本地时间确保日期正确
      final now = DateTime.now();
      final logDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, now.hour, now.minute, now.second);
      final log = Log(
        id: '', // 后端会生成ID
        userId: widget.user.id,
        userName: widget.user.username,
        action: _actionController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        quadrant: _selectedQuadrant,
        isCompleted: 0, // 新创建的日志默认未完成
        createdAt: logDate,
        metadata: metadata,
        relatedTaskId: _selectedTaskId,
      );

      await ApiService.createLog(log);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('日志创建成功'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建日志失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      } else {
        _isSaving = false;
      }
    }
  }

  void _addKeyword() {
    final keyword = _keywordInputController.text.trim();
    if (keyword.isNotEmpty && !_keywords.contains(keyword)) {
      setState(() {
        _keywords.add(keyword);
        _keywordInputController.clear();
      });
    }
  }

  void _removeKeyword(String keyword) {
    setState(() {
      _keywords.remove(keyword);
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

  // 获取当前位置
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // 请求位置权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('位置权限被拒绝')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置权限被永久拒绝，请在设置中开启')),
        );
        return;
      }

      // 获取当前位置
      Position position = await Geolocator.getCurrentPosition(
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
        _locationName = '${convertedLat.toStringAsFixed(6)}, ${convertedLon.toStringAsFixed(6)}';
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
      setState(() {
        _isLoadingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取位置失败: $e')),
      );
    }
  }

  // 清除位置信息
  void _clearLocation() {
    setState(() {
      _locationName = null;
      _latitude = null;
      _longitude = null;
    });
  }

  String _getCategoryText(String category) {
    switch (category) {
      case 'work':
        return '工作';
      case 'meeting':
        return '会议';
      case 'learning':
        return '学习';
      case 'personal':
        return '个人';
      default:
        return category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'work':
        return Colors.blue;
      case 'meeting':
        return Colors.purple;
      case 'learning':
        return Colors.green;
      case 'personal':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getWeatherText(String weather) {
    switch (weather) {
      case 'sunny':
        return '☀️ 晴天';
      case 'cloudy':
        return '☁️ 多云';
      case 'light_rain':
        return '🌦️ 小雨';
      case 'heavy_rain':
        return '🌧️ 大雨';
      case 'snow':
        return '❄️ 下雪';
      case 'storm':
        return '⛈️ 暴风雨';
      case 'fog':
        return '🌫️ 雾';
      default:
        return weather;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加日志'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveLog,
            child: Text(
              _isSaving ? '保存中...' : '保存',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 日期选择
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
                title: const Text('日期'),
                subtitle: Text('${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            // 图片上传
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '图片',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('从相册选择'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('拍照'),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
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
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 地理位置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '地理位置',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_locationName != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearLocation,
                            tooltip: '清除位置',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_locationName != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _locationName!,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                        icon: _isLoadingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.location_on),
                        label: Text(_isLoadingLocation ? '获取中...' : '获取当前位置'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 标题输入
            TextFormField(
              controller: _actionController,
              decoration: const InputDecoration(
                labelText: '日志标题 *',
                hintText: '输入日志标题',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入日志标题';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 内容输入
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '日志内容 *',
                hintText: '输入日志详细内容',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入日志内容';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 类别选择
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '类别',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['work', 'meeting', 'learning', 'personal'].map((category) {
                        final isSelected = _selectedCategory == category;
                        return ChoiceChip(
                          label: Text(_getCategoryText(category)),
                          selected: isSelected,
                          selectedColor: _getCategoryColor(category).withOpacity(0.3),
                          backgroundColor: Colors.grey[200],
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          avatar: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: _getCategoryColor(category),
                                  size: 18,
                                )
                              : null,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 天气选择
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '天气',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['sunny', 'cloudy', 'light_rain', 'heavy_rain', 'snow', 'storm', 'fog'].map((weather) {
                        final isSelected = _selectedWeather == weather;
                        return ChoiceChip(
                          label: Text(_getWeatherText(weather)),
                          selected: isSelected,
                          selectedColor: Colors.blue.withOpacity(0.3),
                          backgroundColor: Colors.grey[200],
                          onSelected: (selected) {
                            setState(() {
                              _selectedWeather = weather;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 关键词
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '关键词',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _keywordInputController,
                            decoration: const InputDecoration(
                              hintText: '输入关键词',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addKeyword(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addKeyword,
                          child: const Text('添加'),
                        ),
                      ],
                    ),
                    if (_keywords.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _keywords.map((keyword) {
                          return Chip(
                            label: Text(keyword),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _removeKeyword(keyword),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 关联任务
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '关联任务',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingTasks)
                      const Center(child: CircularProgressIndicator())
                    else if (_tasks.isEmpty)
                      const Text('暂无可关联的任务')
                    else
                      Column(
                        children: _tasks.take(5).map((task) {
                          final isSelected = _selectedTaskEdits.containsKey(task.id);
                          return CheckboxListTile(
                            title: Text(task.title),
                            subtitle: Text(task.description),
                            value: isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedTaskEdits[task.id] = _AssociatedTaskEdit();
                                  _selectedTaskId ??= task.id;
                                } else {
                                  _selectedTaskEdits.remove(task.id);
                                  if (_selectedTaskId == task.id) {
                                    _selectedTaskId = _selectedTaskEdits.isNotEmpty ? _selectedTaskEdits.keys.first : null;
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssociatedTaskEdit {
  String feeling = 'neutral';
  String note = '';
}

