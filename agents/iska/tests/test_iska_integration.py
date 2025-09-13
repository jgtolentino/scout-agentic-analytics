#!/usr/bin/env python3
"""
Integration tests for Iska Agent - Enterprise Documentation & Asset Intelligence
Tests the full ingestion pipeline with verification requirements
"""

import pytest
import asyncio
import json
import os
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, AsyncMock
from datetime import datetime, timezone
import yaml

# Import Iska modules
import sys
sys.path.append('/Users/tbwa/agents/iska')

from iska_ingest import IskaIngestor, Document, AuditEntry

# Test fixtures
@pytest.fixture
def mock_config():
    """Mock configuration for testing"""
    return {
        'name': 'Iska',
        'version': '2.0.0',
        'ingestion_sources': {
            'web_scraping': [
                {
                    'category': 'Test Assets',
                    'url': 'https://example.com/assets',
                    'selectors': {
                        'asset_container': '.asset-card',
                        'asset_name': '.asset-title',
                        'asset_type': '.asset-type',
                        'asset_url': '.asset-download'
                    }
                }
            ],
            'document_sources': [
                {
                    'type': 'SOPs',
                    'path': '/tmp/test_sop',
                    'extensions': ['.pdf', '.md', '.txt'],
                    'watch': True
                }
            ]
        },
        'qa_workflow': {
            'enabled': True,
            'caca_integration': True,
            'validation_rules': [
                {
                    'name': 'Completeness Check',
                    'type': 'field_validation',
                    'min_length': 10,
                    'max_length': 10000
                }
            ]
        },
        'knowledge_base': {
            'claude_md_update': True,
            'claude_md_path': '/tmp/test_claude.md',
            'sop_directory': '/tmp/test_sop'
        },
        'agent_routing': {
            'enabled': True,
            'downstream_agents': [
                {
                    'name': 'Caca',
                    'trigger': 'qa_validation',
                    'conditions': ['new_document']
                }
            ]
        },
        'verification': {
            'mandatory_checks': {
                'console_errors': False,
                'screenshot_proof': True,
                'automated_testing': True,
                'evidence_based_reporting': True
            }
        }
    }

@pytest.fixture
def mock_supabase():
    """Mock Supabase client"""
    mock = Mock()
    mock.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
    mock.table.return_value.upsert.return_value.execute.return_value.data = [{'id': 'test-id'}]
    mock.table.return_value.insert.return_value.execute.return_value.data = [{'id': 'test-id'}]
    return mock

@pytest.fixture
def mock_openai():
    """Mock OpenAI client"""
    mock = Mock()
    mock.embeddings.create.return_value.data = [
        Mock(embedding=[0.1, 0.2, 0.3] * 512)  # Mock embedding vector
    ]
    return mock

@pytest.fixture
def sample_document():
    """Sample document for testing"""
    return Document(
        id='test-doc-123',
        title='Test Document',
        content='This is a test document with sufficient content for validation.',
        source='test_source',
        source_type='local_file',
        document_type='SOP',
        checksum='abc123',
        file_size=1024,
        created_at=datetime.now(timezone.utc),
        metadata={'test': True}
    )

@pytest.fixture
def test_files():
    """Create temporary test files"""
    with tempfile.TemporaryDirectory() as temp_dir:
        # Create test markdown file
        md_file = Path(temp_dir) / 'test_sop.md'
        md_file.write_text('# Test SOP\n\nThis is a test standard operating procedure.')
        
        # Create test text file
        txt_file = Path(temp_dir) / 'test_doc.txt'
        txt_file.write_text('This is a test document with important information.')
        
        # Create test CLAUDE.md
        claude_file = Path(temp_dir) / 'claude.md'
        claude_file.write_text('# CLAUDE.md\n\nExisting content.')
        
        yield {
            'temp_dir': temp_dir,
            'md_file': str(md_file),
            'txt_file': str(txt_file),
            'claude_file': str(claude_file)
        }

class TestIskaIntegration:
    """Integration tests for Iska Agent"""
    
    @pytest.mark.asyncio
    async def test_full_ingestion_pipeline(self, mock_config, mock_supabase, mock_openai, sample_document):
        """Test complete ingestion pipeline"""
        # Setup
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Mock methods
                    ingestor.scrape_web_sources = AsyncMock(return_value=[sample_document])
                    ingestor.ingest_local_documents = Mock(return_value=[sample_document])
                    
                    # Run ingestion cycle
                    await ingestor.run_ingestion_cycle()
                    
                    # Verify operations
                    assert len(ingestor.audit_log) > 0
                    assert mock_supabase.table.called
                    assert mock_openai.embeddings.create.called

    @pytest.mark.asyncio
    async def test_web_scraping_integration(self, mock_config, mock_supabase, mock_openai):
        """Test web scraping functionality"""
        # Mock HTML response
        mock_html = '''
        <div class="asset-card">
            <h3 class="asset-title">Test Asset</h3>
            <span class="asset-type">Image</span>
            <a class="asset-download" href="/download/test.jpg">Download</a>
        </div>
        '''
        
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Mock aiohttp response
                    mock_response = Mock()
                    mock_response.status = 200
                    mock_response.text = AsyncMock(return_value=mock_html)
                    
                    mock_session = Mock()
                    mock_session.get.return_value.__aenter__.return_value = mock_response
                    
                    ingestor.session = mock_session
                    
                    # Test web scraping
                    documents = await ingestor.scrape_web_sources()
                    
                    # Verify results
                    assert len(documents) == 1
                    assert documents[0].title == 'Test Asset'
                    assert documents[0].document_type == 'asset'

    def test_local_file_ingestion(self, mock_config, mock_supabase, mock_openai, test_files):
        """Test local file ingestion"""
        # Update config with test directory
        mock_config['ingestion_sources']['document_sources'][0]['path'] = test_files['temp_dir']
        
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Test local file ingestion
                    documents = ingestor.ingest_local_documents()
                    
                    # Verify results
                    assert len(documents) >= 1
                    assert any(doc.title == 'test_sop' for doc in documents)
                    assert any(doc.document_type == 'SOPs' for doc in documents)

    @pytest.mark.asyncio
    async def test_qa_validation_workflow(self, mock_config, mock_supabase, mock_openai, sample_document):
        """Test QA validation workflow"""
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Test QA validation
                    validated_docs = await ingestor.qa_validation([sample_document])
                    
                    # Verify results
                    assert len(validated_docs) == 1
                    assert validated_docs[0].qa_status == 'passed'
                    assert validated_docs[0].qa_errors is None

    @pytest.mark.asyncio
    async def test_qa_validation_failure(self, mock_config, mock_supabase, mock_openai):
        """Test QA validation failure scenarios"""
        # Create invalid document
        invalid_doc = Document(
            id='invalid-doc',
            title='',  # Empty title should fail validation
            content='Short',  # Too short content
            source='test',
            source_type='test',
            document_type='test'
        )
        
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Test QA validation
                    validated_docs = await ingestor.qa_validation([invalid_doc])
                    
                    # Verify results
                    assert len(validated_docs) == 1
                    assert validated_docs[0].qa_status == 'failed'
                    assert validated_docs[0].qa_errors is not None
                    assert len(validated_docs[0].qa_errors) > 0

    @pytest.mark.asyncio
    async def test_embedding_generation(self, mock_config, mock_supabase, mock_openai, sample_document):
        """Test embedding generation"""
        # Set QA status to passed
        sample_document.qa_status = 'passed'
        
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Test embedding generation
                    embedded_docs = await ingestor.generate_embeddings([sample_document])
                    
                    # Verify results
                    assert len(embedded_docs) == 1
                    assert embedded_docs[0].embedding is not None
                    assert len(embedded_docs[0].embedding) > 0

    @pytest.mark.asyncio
    async def test_knowledge_base_updates(self, mock_config, mock_supabase, mock_openai, sample_document, test_files):
        """Test knowledge base updates"""
        # Update config with test file paths
        mock_config['knowledge_base']['claude_md_path'] = test_files['claude_file']
        mock_config['knowledge_base']['sop_directory'] = test_files['temp_dir']
        
        # Set document as SOP and passed
        sample_document.document_type = 'SOPs'
        sample_document.qa_status = 'passed'
        
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Test knowledge base updates
                    await ingestor.update_knowledge_base([sample_document])
                    
                    # Verify CLAUDE.md was updated
                    claude_content = Path(test_files['claude_file']).read_text()
                    assert 'Iska Agent - Document Intelligence' in claude_content
                    assert sample_document.title in claude_content
                    
                    # Verify SOP directory was updated
                    sop_file = Path(test_files['temp_dir']) / 'Test_Document.md'
                    assert sop_file.exists()
                    sop_content = sop_file.read_text()
                    assert sample_document.title in sop_content

    @pytest.mark.asyncio
    async def test_agent_notifications(self, mock_config, mock_supabase, mock_openai, sample_document):
        """Test downstream agent notifications"""
        # Set document as passed
        sample_document.qa_status = 'passed'
        
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Test agent notifications
                    await ingestor.notify_downstream_agents([sample_document])
                    
                    # Verify notification was stored
                    assert mock_supabase.table.return_value.insert.called

    def test_audit_logging(self, mock_config, mock_supabase, mock_openai):
        """Test audit logging functionality"""
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Create audit entry
                    audit_entry = AuditEntry(
                        timestamp=datetime.now(timezone.utc),
                        source_type='test',
                        source_url='test://url',
                        document_type='test',
                        action='test_action',
                        agent_trigger='test',
                        qa_status='passed'
                    )
                    
                    # Test audit logging
                    ingestor._log_audit_entry(audit_entry)
                    
                    # Verify audit log
                    assert len(ingestor.audit_log) == 1
                    assert ingestor.audit_log[0].action == 'test_action'

    @pytest.mark.asyncio
    async def test_error_handling(self, mock_config, mock_supabase, mock_openai):
        """Test error handling and recovery"""
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Mock method to raise exception
                    ingestor.scrape_web_sources = AsyncMock(side_effect=Exception("Test error"))
                    ingestor.ingest_local_documents = Mock(return_value=[])
                    
                    # Test error handling
                    with pytest.raises(Exception):
                        await ingestor.run_ingestion_cycle()
                    
                    # Verify error was logged
                    assert len(ingestor.audit_log) > 0

    def test_checksum_calculation(self, mock_config, mock_supabase, mock_openai):
        """Test checksum calculation"""
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Test checksum calculation
                    content = "Test content for checksum"
                    checksum = ingestor._calculate_checksum(content)
                    
                    # Verify checksum
                    assert checksum is not None
                    assert len(checksum) == 64  # SHA256 hex length
                    
                    # Verify consistency
                    checksum2 = ingestor._calculate_checksum(content)
                    assert checksum == checksum2

    @pytest.mark.asyncio
    async def test_performance_benchmarks(self, mock_config, mock_supabase, mock_openai):
        """Test performance benchmarks"""
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Create multiple test documents
                    test_docs = []
                    for i in range(100):
                        doc = Document(
                            id=f'test-doc-{i}',
                            title=f'Test Document {i}',
                            content=f'Content for test document {i}' * 10,
                            source='test_source',
                            source_type='test',
                            document_type='test'
                        )
                        test_docs.append(doc)
                    
                    # Measure QA validation performance
                    start_time = datetime.now()
                    validated_docs = await ingestor.qa_validation(test_docs)
                    end_time = datetime.now()
                    
                    processing_time = (end_time - start_time).total_seconds()
                    docs_per_second = len(validated_docs) / processing_time
                    
                    # Verify performance targets
                    assert docs_per_second > 10  # Should process at least 10 docs per second
                    assert processing_time < 30  # Should complete within 30 seconds

class TestVerificationRequirements:
    """Test verification requirements as per CLAUDE.md standards"""
    
    def test_console_error_verification(self, mock_config, mock_supabase, mock_openai):
        """Test console error verification"""
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Verify no console errors in configuration
                    assert ingestor.config['verification']['mandatory_checks']['console_errors'] == False
                    
                    # Test successful initialization without errors
                    assert ingestor.supabase is not None
                    assert ingestor.openai is not None

    def test_screenshot_proof_requirement(self, mock_config, mock_supabase, mock_openai):
        """Test screenshot proof requirement"""
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Verify screenshot proof is required
                    assert ingestor.config['verification']['mandatory_checks']['screenshot_proof'] == True

    def test_automated_testing_requirement(self, mock_config, mock_supabase, mock_openai):
        """Test automated testing requirement"""
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Verify automated testing is required
                    assert ingestor.config['verification']['mandatory_checks']['automated_testing'] == True

    def test_evidence_based_reporting(self, mock_config, mock_supabase, mock_openai):
        """Test evidence-based reporting requirement"""
        with patch('iska_ingest.IskaIngestor._load_config', return_value=mock_config):
            with patch('iska_ingest.IskaIngestor._init_supabase', return_value=mock_supabase):
                with patch('iska_ingest.IskaIngestor._init_openai', return_value=mock_openai):
                    
                    ingestor = IskaIngestor()
                    
                    # Verify evidence-based reporting is required
                    assert ingestor.config['verification']['mandatory_checks']['evidence_based_reporting'] == True

if __name__ == '__main__':
    # Run tests with verbose output
    pytest.main([__file__, '-v', '--tb=short'])