import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/document_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/ca_providers.dart';

class CADocumentReviewPage extends ConsumerStatefulWidget {
  const CADocumentReviewPage({super.key});

  @override
  ConsumerState<CADocumentReviewPage> createState() => _CADocumentReviewPageState();
}

class _CADocumentReviewPageState extends ConsumerState<CADocumentReviewPage> {
  String _searchQuery = '';
  DocumentStatus? _selectedStatus = DocumentStatus.pending;
  String _sortBy = 'uploadedAt';
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final pendingDocuments = ref.watch(pendingDocumentsProvider);
    
    return currentUser.when(
      data: (user) {
        if (user == null || (!user.isCA && !user.isAdmin)) {
          return _buildUnauthorizedPage();
        }
        return _buildReviewPage(pendingDocuments);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _buildErrorPage(error.toString()),
    );
  }

  Widget _buildReviewPage(AsyncValue<List<DocumentModel>> documentsAsync) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Review'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => ref.refresh(pendingDocumentsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilterSection(),
          
          // Documents List
          Expanded(
            child: documentsAsync.when(
              data: (documents) => _buildDocumentsList(documents),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorContent(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search documents...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Filter row
          Row(
            children: [
              // Status filter
              Expanded(
                child: DropdownButtonFormField<DocumentStatus?>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(
                      value: DocumentStatus.pending,
                      child: Row(
                        children: [
                          Icon(Icons.pending, size: 16, color: AppTheme.warningColor),
                          SizedBox(width: 8),
                          Text('Pending'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: DocumentStatus.verified,
                      child: Row(
                        children: [
                          Icon(Icons.verified, size: 16, color: AppTheme.successColor),
                          SizedBox(width: 8),
                          Text('Verified'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: DocumentStatus.rejected,
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 16, color: AppTheme.errorColor),
                          SizedBox(width: 8),
                          Text('Rejected'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingM),
              
              // Sort button
              OutlinedButton.icon(
                onPressed: _showSortDialog,
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
                label: const Text('Sort'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(List<DocumentModel> allDocuments) {
    // Filter documents based on search and status
    List<DocumentModel> filteredDocuments = allDocuments.where((doc) {
      bool matchesSearch = _searchQuery.isEmpty ||
          doc.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          doc.uploaderName.toLowerCase().contains(_searchQuery.toLowerCase());
      
      bool matchesStatus = _selectedStatus == null || doc.status == _selectedStatus;
      
      return matchesSearch && matchesStatus;
    }).toList();

    // Sort documents
    filteredDocuments.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'uploaderName':
          comparison = a.uploaderName.compareTo(b.uploaderName);
          break;
        case 'uploadedAt':
        default:
          comparison = a.uploadedAt.compareTo(b.uploadedAt);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    if (filteredDocuments.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(pendingDocumentsProvider.future),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: filteredDocuments.length,
        itemBuilder: (context, index) {
          final document = filteredDocuments[index];
          return FadeInUp(
            duration: Duration(milliseconds: 300 + (index * 100)),
            child: _buildDocumentCard(document),
          );
        },
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel document) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name,
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Uploaded by ${document.uploaderName}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(document.status),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            // Document details
            Row(
              children: [
                Icon(
                  _getDocumentIcon(document.type),
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  document.type.displayName,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                const Icon(
                  Icons.cloud_upload,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(document.uploadedAt),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            
            if (document.description.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(
                document.description,
                style: AppTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            const SizedBox(height: AppTheme.spacingM),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewDocument(document),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                if (document.status == DocumentStatus.pending) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveDocument(document),
                      icon: const Icon(
                        Icons.verified,
                        color: AppTheme.successColor,
                      ),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectDocument(document),
                      icon: const Icon(
                        Icons.close,
                        color: AppTheme.errorColor,
                      ),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(DocumentStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case DocumentStatus.pending:
        color = AppTheme.warningColor;
        icon = Icons.pending;
        label = 'Pending';
        break;
      case DocumentStatus.verified:
        color = AppTheme.successColor;
        icon = Icons.verified;
        label = 'Verified';
        break;
      case DocumentStatus.rejected:
        color = AppTheme.errorColor;
        icon = Icons.cancel;
        label = 'Rejected';
        break;
      default:
        color = AppTheme.textSecondary;
        icon = Icons.help;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    if (_searchQuery.isNotEmpty) {
      message = 'No documents found matching "$_searchQuery"';
      icon = Icons.search_off;
    } else if (_selectedStatus != null) {
      message = 'No ${_selectedStatus!.displayName.toLowerCase()} documents';
      icon = Icons.folder_open;
    } else {
      message = 'No documents to review';
      icon = Icons.description;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.1),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              message,
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty || _selectedStatus != null) ...[
              const SizedBox(height: AppTheme.spacingM),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedStatus = null;
                  });
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Documents'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Upload Date'),
              value: 'uploadedAt',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Document Name'),
              value: 'name',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Uploader Name'),
              value: 'uploaderName',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Ascending Order'),
              value: _sortAscending,
              onChanged: (value) {
                setState(() {
                  _sortAscending = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _viewDocument(DocumentModel document) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      document.name,
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: AppTheme.spacingM),
              
              // Document metadata
              _buildMetadataRow('Type', document.type.displayName),
              _buildMetadataRow('Uploaded by', document.uploaderName),
              _buildMetadataRow('Upload date', _formatDate(document.uploadedAt)),
              _buildMetadataRow('File size', _formatFileSize(document.fileSize)),
              if (document.description.isNotEmpty)
                _buildMetadataRow('Description', document.description),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Document viewer with real preview functionality
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.dividerColor),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: _buildDocumentPreview(document),
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Action buttons
              if (document.status == DocumentStatus.pending)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectDocument(document);
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveDocument(document);
                        },
                        icon: const Icon(Icons.verified),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _approveDocument(DocumentModel document) {
    final commentsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to approve "${document.name}"?'),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: commentsController,
              decoration: const InputDecoration(
                labelText: 'Comments (optional)',
                hintText: 'Add approval comments...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                await ref.read(documentReviewProvider.notifier).approveDocument(
                  document.id,
                  commentsController.text.trim(),
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Document approved successfully'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to approve document: $error'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _rejectDocument(DocumentModel document) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject "${document.name}"?'),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                hintText: 'Please provide a reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                await ref.read(documentReviewProvider.notifier).rejectDocument(
                  document.id,
                  reasonController.text.trim(),
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Document rejected'),
                      backgroundColor: AppTheme.warningColor,
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to reject document: $error'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getDocumentIcon(DocumentType type) {
    switch (type) {
      case DocumentType.diploma:
        return Icons.school;
      case DocumentType.certificate:
        return Icons.verified;
      case DocumentType.identification:
        return Icons.badge;
      case DocumentType.transcript:
        return Icons.description;
      case DocumentType.other:
      default:
        return Icons.description;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildUnauthorizedPage() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'Access Denied',
                style: AppTheme.titleLarge.copyWith(color: AppTheme.errorColor),
              ),
              const SizedBox(height: AppTheme.spacingM),
              const Text('You do not have permission to review documents.'),
              const SizedBox(height: AppTheme.spacingL),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPage(String error) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'Something went wrong',
                style: AppTheme.titleLarge.copyWith(color: AppTheme.errorColor),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: AppTheme.spacingL),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Failed to load documents',
              style: AppTheme.titleMedium.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton(
              onPressed: () => ref.refresh(pendingDocumentsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentPreview(DocumentModel document) {
    switch (document.mimeType.toLowerCase()) {
      case 'application/pdf':
        return _buildPDFPreview(document);
      case 'image/jpeg':
      case 'image/jpg':
      case 'image/png':
      case 'image/gif':
        return _buildImagePreview(document);
      case 'text/plain':
        return _buildTextPreview(document);
      default:
        return _buildGenericPreview(document);
    }
  }

  Widget _buildPDFPreview(DocumentModel document) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'PDF Document',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            document.fileName,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingM),
          ElevatedButton.icon(
            onPressed: () => _openDocumentInNewTab(document),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(DocumentModel document) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              child: document.fileUrl.isNotEmpty
                  ? Image.network(
                      document.fileUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: AppTheme.textSecondary,
                        );
                      },
                    )
                  : const Icon(
                      Icons.image,
                      size: 64,
                      color: AppTheme.textSecondary,
                    ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Image Document',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            document.fileName,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingM),
          ElevatedButton.icon(
            onPressed: () => _openDocumentInNewTab(document),
            icon: const Icon(Icons.open_in_new),
            label: const Text('View Full Size'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPreview(DocumentModel document) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.text_snippet,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Text Document',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            document.fileName,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingM),
          ElevatedButton.icon(
            onPressed: () => _openDocumentInNewTab(document),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Text File'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericPreview(DocumentModel document) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getDocumentIcon(document.type),
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Document Preview',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            document.fileName,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'File Type: ${document.mimeType}',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          ElevatedButton.icon(
            onPressed: () => _openDocumentInNewTab(document),
            icon: const Icon(Icons.download),
            label: const Text('Download to View'),
          ),
        ],
      ),
    );
  }

  void _openDocumentInNewTab(DocumentModel document) async {
    try {
      if (document.fileUrl.isNotEmpty) {
        final uri = Uri.parse(document.fileUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening document in external application...'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        } else {
          throw Exception('Could not launch document URL');
        }
      } else {
        throw Exception('Document URL not available');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open document: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
} 
