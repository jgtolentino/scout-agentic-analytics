#!/usr/bin/env python3
"""
DataOS Documentation Extractor & Diff Engine
Production-grade documentation extraction, archiving, and version comparison
"""

import os
import sys
import json
import asyncio
import argparse
import hashlib
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Union, Tuple, Any
from urllib.parse import urlparse, urljoin
from enum import Enum
import logging
import re
from dataclasses import dataclass, asdict
import subprocess
import tempfile

# Third-party imports
try:
    from playwright.async_api import async_playwright
    from bs4 import BeautifulSoup
    from markdownify import markdownify
    from deepdiff import DeepDiff
    from PIL import Image
    import aiohttp
    import schedule
    import yaml
    import requests
    from jinja2 import Template
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Install with: pip install playwright beautifulsoup4 markdownify deepdiff pillow aiohttp schedule pyyaml jinja2 requests")
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('dataos-docs-extractor')

class ExtractionMethod(Enum):
    STATIC = "static"
    DYNAMIC = "dynamic"
    HYBRID = "hybrid"
    API = "api"

class DiffMode(Enum):
    SEMANTIC = "semantic"
    VISUAL = "visual"
    BOTH = "both"
    NONE = "none"

class OutputFormat(Enum):
    HTML = "html"
    MARKDOWN = "markdown"
    PDF = "pdf"
    ALL = "all"

@dataclass
class ExtractionConfig:
    source_url: str
    output_format: OutputFormat = OutputFormat.MARKDOWN
    extraction_method: ExtractionMethod = ExtractionMethod.HYBRID
    auth: Optional[Dict] = None
    max_depth: int = 10
    max_pages: int = 10000
    concurrent_pages: int = 5
    timeout: int = 300
    ignore_patterns: List[str] = None

@dataclass
class ArchiveMetadata:
    source_url: str
    timestamp: datetime
    extraction_method: str
    total_pages: int
    extraction_time: float
    format: str
    checksum: str
    toc: Dict
    
@dataclass 
class DiffResult:
    timestamp: datetime
    archive1_date: str
    archive2_date: str
    total_changes: int
    added_sections: int
    removed_sections: int
    modified_sections: int
    semantic_diff_path: Optional[str] = None
    visual_diff_path: Optional[str] = None
    change_details: List[Dict] = None

class DocumentExtractor:
    """Core extraction engine supporting multiple methods"""
    
    def __init__(self, config: ExtractionConfig):
        self.config = config
        self.visited_urls = set()
        self.page_content = {}
        self.toc = {"title": "Table of Contents", "sections": []}
        self.start_time = datetime.now()
        
    async def extract(self) -> Tuple[str, ArchiveMetadata]:
        """Extract documentation using configured method"""
        logger.info(f"Starting extraction from {self.config.source_url}")
        
        if self.config.extraction_method == ExtractionMethod.STATIC:
            archive_path = await self._extract_static()
        elif self.config.extraction_method == ExtractionMethod.DYNAMIC:
            archive_path = await self._extract_dynamic()
        elif self.config.extraction_method == ExtractionMethod.HYBRID:
            archive_path = await self._extract_hybrid()
        else:
            raise ValueError(f"Unsupported extraction method: {self.config.extraction_method}")
            
        # Generate metadata
        metadata = self._generate_metadata(archive_path)
        return archive_path, metadata
        
    async def _extract_static(self) -> str:
        """Extract using wget for static content"""
        archive_path = self._create_archive_dir()
        
        wget_cmd = [
            'wget',
            '--mirror',
            '--convert-links',
            '--adjust-extension',
            '--page-requisites',
            '--no-parent',
            '--directory-prefix', archive_path,
            '--user-agent', 'DataOS-Docs-Bot/1.0',
            self.config.source_url
        ]
        
        logger.info(f"Running wget: {' '.join(wget_cmd)}")
        process = await asyncio.create_subprocess_exec(
            *wget_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            logger.error(f"wget failed: {stderr.decode()}")
            raise RuntimeError("Static extraction failed")
            
        # Convert to desired format if needed
        if self.config.output_format != OutputFormat.HTML:
            await self._convert_format(archive_path)
            
        return archive_path
        
    async def _extract_dynamic(self) -> str:
        """Extract using Playwright for dynamic content"""
        archive_path = self._create_archive_dir()
        
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context(
                user_agent='DataOS-Docs-Bot/1.0'
            )
            
            # Handle authentication if provided
            if self.config.auth:
                await self._setup_auth(context)
                
            # Start crawling
            await self._crawl_dynamic(context, self.config.source_url, archive_path)
            
            await browser.close()
            
        # Convert format if needed
        if self.config.output_format != OutputFormat.HTML:
            await self._convert_format(archive_path)
            
        return archive_path
        
    async def _extract_hybrid(self) -> str:
        """Use static for simple pages, dynamic for JS-heavy pages"""
        # First do a static crawl
        archive_path = await self._extract_static()
        
        # Then check for dynamic content indicators
        dynamic_pages = await self._identify_dynamic_pages(archive_path)
        
        if dynamic_pages:
            logger.info(f"Found {len(dynamic_pages)} pages with dynamic content")
            # Re-extract those pages dynamically
            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=True)
                context = await browser.new_context()
                
                for page_url in dynamic_pages:
                    await self._extract_single_page_dynamic(context, page_url, archive_path)
                    
                await browser.close()
                
        return archive_path
        
    async def _crawl_dynamic(self, context, url: str, archive_path: str, depth: int = 0):
        """Recursively crawl pages using Playwright"""
        if depth > self.config.max_depth or url in self.visited_urls:
            return
            
        if len(self.visited_urls) >= self.config.max_pages:
            logger.warning(f"Reached max pages limit: {self.config.max_pages}")
            return
            
        self.visited_urls.add(url)
        logger.info(f"Crawling: {url} (depth: {depth})")
        
        page = await context.new_page()
        try:
            await page.goto(url, wait_until='networkidle', timeout=self.config.timeout * 1000)
            
            # Wait for any dynamic content
            await page.wait_for_load_state('domcontentloaded')
            await asyncio.sleep(2)  # Extra wait for JS rendering
            
            # Extract content
            content = await page.content()
            self._save_page_content(url, content, archive_path)
            
            # Extract TOC structure
            await self._extract_toc_from_page(page, url)
            
            # Find all links
            links = await page.evaluate('''() => {
                return Array.from(document.querySelectorAll('a[href]'))
                    .map(a => a.href)
                    .filter(href => href && !href.startsWith('#') && !href.startsWith('javascript:'));
            }''')
            
            # Filter and crawl child pages
            base_domain = urlparse(self.config.source_url).netloc
            for link in links:
                if urlparse(link).netloc == base_domain and link not in self.visited_urls:
                    await self._crawl_dynamic(context, link, archive_path, depth + 1)
                    
        except Exception as e:
            logger.error(f"Error crawling {url}: {e}")
        finally:
            await page.close()
            
    def _save_page_content(self, url: str, content: str, archive_path: str):
        """Save page content to archive"""
        parsed_url = urlparse(url)
        path_parts = parsed_url.path.strip('/').split('/')
        
        if not path_parts or path_parts == ['']:
            filename = 'index.html'
        else:
            filename = os.path.join(*path_parts)
            if not filename.endswith('.html'):
                filename += '.html'
                
        file_path = os.path.join(archive_path, filename)
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
            
        # Convert to markdown if needed
        if self.config.output_format == OutputFormat.MARKDOWN:
            self._convert_to_markdown(file_path)
            
    def _convert_to_markdown(self, html_path: str):
        """Convert HTML file to Markdown"""
        with open(html_path, 'r', encoding='utf-8') as f:
            html_content = f.read()
            
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Remove script and style elements
        for element in soup(['script', 'style', 'meta', 'link']):
            element.decompose()
            
        # Convert to markdown
        markdown_content = markdownify(str(soup), heading_style="ATX")
        
        # Save markdown file
        md_path = html_path.replace('.html', '.md')
        with open(md_path, 'w', encoding='utf-8') as f:
            f.write(markdown_content)
            
    async def _extract_toc_from_page(self, page, url: str):
        """Extract table of contents structure from page"""
        toc_data = await page.evaluate('''() => {
            const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
            return Array.from(headings).map(h => ({
                level: parseInt(h.tagName[1]),
                text: h.textContent.trim(),
                id: h.id || null
            }));
        }''')
        
        if toc_data:
            self.toc['sections'].append({
                'url': url,
                'headings': toc_data
            })
            
    def _create_archive_dir(self) -> str:
        """Create timestamped archive directory"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        archive_path = os.path.join('/dataos-archives', timestamp)
        os.makedirs(archive_path, exist_ok=True)
        return archive_path
        
    def _generate_metadata(self, archive_path: str) -> ArchiveMetadata:
        """Generate archive metadata"""
        extraction_time = (datetime.now() - self.start_time).total_seconds()
        
        # Calculate checksum of archive
        checksum = self._calculate_archive_checksum(archive_path)
        
        # Count pages
        total_pages = sum(1 for _ in Path(archive_path).rglob('*.html')) + \
                     sum(1 for _ in Path(archive_path).rglob('*.md'))
        
        metadata = ArchiveMetadata(
            source_url=self.config.source_url,
            timestamp=datetime.now(),
            extraction_method=self.config.extraction_method.value,
            total_pages=total_pages,
            extraction_time=extraction_time,
            format=self.config.output_format.value,
            checksum=checksum,
            toc=self.toc
        )
        
        # Save metadata
        metadata_path = os.path.join(archive_path, 'metadata.json')
        with open(metadata_path, 'w') as f:
            json.dump(asdict(metadata), f, indent=2, default=str)
            
        return metadata
        
    def _calculate_archive_checksum(self, archive_path: str) -> str:
        """Calculate SHA256 checksum of archive contents"""
        sha256_hash = hashlib.sha256()
        
        for file_path in sorted(Path(archive_path).rglob('*')):
            if file_path.is_file():
                with open(file_path, 'rb') as f:
                    for byte_block in iter(lambda: f.read(4096), b""):
                        sha256_hash.update(byte_block)
                        
        return sha256_hash.hexdigest()
        
    async def _identify_dynamic_pages(self, archive_path: str) -> List[str]:
        """Identify pages that likely have dynamic content"""
        dynamic_indicators = [
            'react', 'vue', 'angular', 'webpack', '__NEXT_DATA__',
            'window.__INITIAL_STATE__', 'data-reactroot'
        ]
        
        dynamic_pages = []
        
        for html_file in Path(archive_path).rglob('*.html'):
            with open(html_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
            if any(indicator in content for indicator in dynamic_indicators):
                # Reconstruct URL from file path
                rel_path = html_file.relative_to(archive_path)
                url = urljoin(self.config.source_url, str(rel_path))
                dynamic_pages.append(url)
                
        return dynamic_pages
        
    async def _setup_auth(self, context):
        """Setup authentication for private docs"""
        if self.config.auth['method'] == 'cookie':
            cookies = self.config.auth['credentials']['cookies']
            await context.add_cookies(cookies)
        elif self.config.auth['method'] == 'basic':
            # Handle basic auth
            username = self.config.auth['credentials']['username']
            password = self.config.auth['credentials']['password']
            await context.set_http_credentials({
                'username': username,
                'password': password
            })
        # Add more auth methods as needed

class DiffEngine:
    """Semantic and visual diff engine"""
    
    def __init__(self):
        self.logger = logging.getLogger('diff-engine')
        
    async def compute_diff(self, archive1: str, archive2: str, mode: DiffMode) -> DiffResult:
        """Compute diff between two archives"""
        self.logger.info(f"Computing {mode.value} diff between {archive1} and {archive2}")
        
        result = DiffResult(
            timestamp=datetime.now(),
            archive1_date=os.path.basename(archive1),
            archive2_date=os.path.basename(archive2),
            total_changes=0,
            added_sections=0,
            removed_sections=0,
            modified_sections=0,
            change_details=[]
        )
        
        if mode in [DiffMode.SEMANTIC, DiffMode.BOTH]:
            semantic_result = await self._compute_semantic_diff(archive1, archive2)
            result.semantic_diff_path = semantic_result['diff_path']
            result.total_changes += semantic_result['total_changes']
            result.added_sections += semantic_result['added']
            result.removed_sections += semantic_result['removed']
            result.modified_sections += semantic_result['modified']
            result.change_details.extend(semantic_result['details'])
            
        if mode in [DiffMode.VISUAL, DiffMode.BOTH]:
            visual_result = await self._compute_visual_diff(archive1, archive2)
            result.visual_diff_path = visual_result['diff_path']
            result.change_details.extend(visual_result['details'])
            
        return result
        
    async def _compute_semantic_diff(self, archive1: str, archive2: str) -> Dict:
        """Compute semantic diff between archives"""
        diff_dir = self._create_diff_dir(archive1, archive2)
        diff_path = os.path.join(diff_dir, 'semantic_diff.md')
        
        changes = {
            'added': 0,
            'removed': 0,
            'modified': 0,
            'total_changes': 0,
            'details': [],
            'diff_path': diff_path
        }
        
        # Load file lists
        files1 = set(self._get_content_files(archive1))
        files2 = set(self._get_content_files(archive2))
        
        # Find added/removed files
        added_files = files2 - files1
        removed_files = files1 - files2
        common_files = files1 & files2
        
        changes['added'] = len(added_files)
        changes['removed'] = len(removed_files)
        
        # Write diff header
        with open(diff_path, 'w') as f:
            f.write(f"# Documentation Diff Report\n\n")
            f.write(f"**Generated:** {datetime.now().isoformat()}\n")
            f.write(f"**Archive 1:** {archive1}\n")
            f.write(f"**Archive 2:** {archive2}\n\n")
            
            # Summary
            f.write("## Summary\n\n")
            f.write(f"- **Added files:** {len(added_files)}\n")
            f.write(f"- **Removed files:** {len(removed_files)}\n")
            f.write(f"- **Modified files:** TBD\n\n")
            
            # Added files
            if added_files:
                f.write("## Added Files\n\n")
                for file in sorted(added_files):
                    f.write(f"- `{file}`\n")
                    changes['details'].append({
                        'type': 'added',
                        'file': file
                    })
                f.write("\n")
                
            # Removed files
            if removed_files:
                f.write("## Removed Files\n\n")
                for file in sorted(removed_files):
                    f.write(f"- `{file}`\n")
                    changes['details'].append({
                        'type': 'removed',
                        'file': file
                    })
                f.write("\n")
                
            # Modified files
            f.write("## Modified Files\n\n")
            
        # Compare common files
        for rel_path in common_files:
            file1 = os.path.join(archive1, rel_path)
            file2 = os.path.join(archive2, rel_path)
            
            if self._files_differ(file1, file2):
                changes['modified'] += 1
                changes['details'].append({
                    'type': 'modified',
                    'file': rel_path,
                    'diff': self._generate_file_diff(file1, file2)
                })
                
                # Append to diff report
                with open(diff_path, 'a') as f:
                    f.write(f"### {rel_path}\n\n")
                    f.write("```diff\n")
                    f.write(self._generate_file_diff(file1, file2))
                    f.write("\n```\n\n")
                    
        changes['total_changes'] = changes['added'] + changes['removed'] + changes['modified']
        
        return changes
        
    async def _compute_visual_diff(self, archive1: str, archive2: str) -> Dict:
        """Compute visual diff using screenshots"""
        diff_dir = self._create_diff_dir(archive1, archive2)
        visual_dir = os.path.join(diff_dir, 'visual')
        os.makedirs(visual_dir, exist_ok=True)
        
        result = {
            'diff_path': visual_dir,
            'details': []
        }
        
        # For demonstration, we'll compare main index pages
        # In production, this would screenshot and compare multiple key pages
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            
            # Take screenshots of key pages from both archives
            key_pages = ['index.html', 'getting-started.html', 'api-reference.html']
            
            for page_name in key_pages:
                page1_path = os.path.join(archive1, page_name)
                page2_path = os.path.join(archive2, page_name)
                
                if os.path.exists(page1_path) and os.path.exists(page2_path):
                    # Take screenshots
                    page = await browser.new_page()
                    
                    # Screenshot 1
                    await page.goto(f'file://{page1_path}')
                    screenshot1_path = os.path.join(visual_dir, f'{page_name}_v1.png')
                    await page.screenshot(path=screenshot1_path, full_page=True)
                    
                    # Screenshot 2
                    await page.goto(f'file://{page2_path}')
                    screenshot2_path = os.path.join(visual_dir, f'{page_name}_v2.png')
                    await page.screenshot(path=screenshot2_path, full_page=True)
                    
                    await page.close()
                    
                    # Compare images
                    diff_image_path = os.path.join(visual_dir, f'{page_name}_diff.png')
                    similarity = self._compare_images(screenshot1_path, screenshot2_path, diff_image_path)
                    
                    result['details'].append({
                        'page': page_name,
                        'similarity': similarity,
                        'screenshot1': screenshot1_path,
                        'screenshot2': screenshot2_path,
                        'diff_image': diff_image_path
                    })
                    
            await browser.close()
            
        return result
        
    def _get_content_files(self, archive_path: str) -> List[str]:
        """Get list of content files relative to archive root"""
        files = []
        archive_path_obj = Path(archive_path)
        
        for ext in ['*.html', '*.md']:
            for file_path in archive_path_obj.rglob(ext):
                if file_path.name != 'metadata.json':
                    rel_path = file_path.relative_to(archive_path_obj)
                    files.append(str(rel_path))
                    
        return files
        
    def _files_differ(self, file1: str, file2: str) -> bool:
        """Check if two files differ (ignoring trivial changes)"""
        with open(file1, 'r', encoding='utf-8') as f1, open(file2, 'r', encoding='utf-8') as f2:
            content1 = f1.read()
            content2 = f2.read()
            
        # Normalize content (remove timestamps, build IDs, etc)
        content1 = self._normalize_content(content1)
        content2 = self._normalize_content(content2)
        
        return content1 != content2
        
    def _normalize_content(self, content: str) -> str:
        """Normalize content by removing dynamic elements"""
        # Remove timestamps
        content = re.sub(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}', 'TIMESTAMP', content)
        # Remove build IDs
        content = re.sub(r'build-[a-zA-Z0-9]+', 'BUILD-ID', content)
        # Remove version numbers
        content = re.sub(r'v\d+\.\d+\.\d+', 'VERSION', content)
        
        return content
        
    def _generate_file_diff(self, file1: str, file2: str) -> str:
        """Generate unified diff between two files"""
        # Use system diff command for now
        try:
            result = subprocess.run(
                ['diff', '-u', file1, file2],
                capture_output=True,
                text=True
            )
            return result.stdout
        except Exception as e:
            return f"Error generating diff: {e}"
            
    def _compare_images(self, img1_path: str, img2_path: str, diff_path: str) -> float:
        """Compare two images and generate diff visualization"""
        # Simple pixel comparison for demonstration
        # In production, use more sophisticated image comparison
        img1 = Image.open(img1_path)
        img2 = Image.open(img2_path)
        
        # Ensure same size
        if img1.size != img2.size:
            img2 = img2.resize(img1.size)
            
        # Create diff image
        diff = Image.new('RGB', img1.size)
        
        pixels1 = img1.load()
        pixels2 = img2.load()
        pixels_diff = diff.load()
        
        total_pixels = img1.size[0] * img1.size[1]
        different_pixels = 0
        
        for x in range(img1.size[0]):
            for y in range(img1.size[1]):
                if pixels1[x, y] != pixels2[x, y]:
                    pixels_diff[x, y] = (255, 0, 0)  # Red for differences
                    different_pixels += 1
                else:
                    pixels_diff[x, y] = pixels1[x, y]
                    
        diff.save(diff_path)
        
        similarity = 1.0 - (different_pixels / total_pixels)
        return similarity
        
    def _create_diff_dir(self, archive1: str, archive2: str) -> str:
        """Create directory for diff results"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        diff_dir = os.path.join(
            '/dataos-archives/diffs',
            f'{os.path.basename(archive1)}_vs_{os.path.basename(archive2)}_{timestamp}'
        )
        os.makedirs(diff_dir, exist_ok=True)
        return diff_dir

class ChangeAnalyzer:
    """Analyze changes and generate reports"""
    
    def analyze(self, diff_result: DiffResult) -> Dict:
        """Generate comprehensive change analytics"""
        analytics = {
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_changes': diff_result.total_changes,
                'added_sections': diff_result.added_sections,
                'removed_sections': diff_result.removed_sections,
                'modified_sections': diff_result.modified_sections,
                'change_percentage': 0
            },
            'categories': {},
            'recommendations': [],
            'alerts': []
        }
        
        # Calculate change percentage
        total_sections = sum([
            diff_result.added_sections,
            diff_result.removed_sections,
            diff_result.modified_sections
        ])
        
        if total_sections > 0:
            analytics['summary']['change_percentage'] = (
                diff_result.total_changes / total_sections * 100
            )
            
        # Categorize changes
        for change in diff_result.change_details:
            category = self._categorize_change(change)
            if category not in analytics['categories']:
                analytics['categories'][category] = []
            analytics['categories'][category].append(change)
            
        # Generate recommendations
        if diff_result.added_sections > 10:
            analytics['recommendations'].append(
                "Significant new content added. Review for learning impact."
            )
            
        if diff_result.removed_sections > 5:
            analytics['alerts'].append({
                'severity': 'high',
                'message': f"{diff_result.removed_sections} sections removed. Verify no critical content lost."
            })
            
        if analytics['summary']['change_percentage'] > 20:
            analytics['alerts'].append({
                'severity': 'medium',
                'message': f"{analytics['summary']['change_percentage']:.1f}% of documentation changed."
            })
            
        return analytics
        
    def _categorize_change(self, change: Dict) -> str:
        """Categorize a change by type"""
        file_path = change.get('file', '')
        
        if 'api' in file_path.lower():
            return 'api_changes'
        elif 'guide' in file_path.lower() or 'tutorial' in file_path.lower():
            return 'guide_changes'
        elif 'reference' in file_path.lower():
            return 'reference_changes'
        elif 'example' in file_path.lower():
            return 'example_changes'
        else:
            return 'other_changes'

class NotificationService:
    """Handle notifications and webhooks"""
    
    def __init__(self, config: Dict):
        self.config = config
        self.logger = logging.getLogger('notifications')
        
    async def notify(self, event: str, data: Dict):
        """Send notifications about events"""
        if not self.config.get('enabled', True):
            return
            
        channels = self.config.get('channels', [])
        
        for channel in channels:
            try:
                if channel['type'] == 'webhook':
                    await self._send_webhook(channel['url'], event, data)
                elif channel['type'] == 'slack':
                    await self._send_slack(channel, event, data)
                elif channel['type'] == 'email':
                    await self._send_email(channel['recipients'], event, data)
            except Exception as e:
                self.logger.error(f"Failed to send {channel['type']} notification: {e}")
                
    async def _send_webhook(self, url: str, event: str, data: Dict):
        """Send webhook notification"""
        payload = {
            'event': event,
            'timestamp': datetime.now().isoformat(),
            'data': data
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=payload) as response:
                if response.status != 200:
                    raise Exception(f"Webhook failed: {response.status}")
                    
    async def _send_slack(self, config: Dict, event: str, data: Dict):
        """Send Slack notification"""
        webhook_url = config.get('webhook_url') or os.environ.get('SLACK_WEBHOOK')
        
        if not webhook_url:
            raise ValueError("Slack webhook URL not configured")
            
        # Format message based on event
        if event == 'extraction_complete':
            text = f"📚 Documentation extracted from {data['source_url']}\n"
            text += f"Pages: {data['total_pages']} | Time: {data['extraction_time']:.1f}s"
        elif event == 'diff_complete':
            text = f"📊 Documentation changes detected!\n"
            text += f"Added: {data['added_sections']} | Removed: {data['removed_sections']} | Modified: {data['modified_sections']}"
        else:
            text = f"🔔 {event}: {json.dumps(data, indent=2)}"
            
        payload = {
            'text': text,
            'username': 'DataOS Docs Bot',
            'icon_emoji': ':books:'
        }
        
        await self._send_webhook(webhook_url, event, payload)
        
    async def _send_email(self, recipients: List[str], event: str, data: Dict):
        """Send email notification (placeholder)"""
        # Would integrate with SMTP server
        self.logger.info(f"Email notification to {recipients}: {event}")

class DataOSDocsExtractor:
    """Main orchestrator class"""
    
    def __init__(self):
        self.logger = logging.getLogger('dataos-extractor')
        self.config = self._load_config()
        self.notification_service = NotificationService(
            self.config.get('notifications', {})
        )
        
    def _load_config(self) -> Dict:
        """Load configuration from YAML"""
        config_path = os.path.join(
            os.path.dirname(__file__),
            '../../dataos-docs-extractor.yaml'
        )
        
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                yaml_content = yaml.safe_load(f)
                return yaml_content.get('agent', {}).get('config', {})
        return {}
        
    async def extract(self, args: argparse.Namespace) -> Dict:
        """Execute extraction command"""
        config = ExtractionConfig(
            source_url=args.source,
            output_format=OutputFormat(args.format),
            extraction_method=ExtractionMethod(args.method) if hasattr(args, 'method') else ExtractionMethod.HYBRID,
            auth=json.loads(args.auth) if hasattr(args, 'auth') and args.auth else None
        )
        
        extractor = DocumentExtractor(config)
        archive_path, metadata = await extractor.extract()
        
        # Send notification
        await self.notification_service.notify('extraction_complete', {
            'source_url': config.source_url,
            'archive_path': archive_path,
            'total_pages': metadata.total_pages,
            'extraction_time': metadata.extraction_time
        })
        
        return {
            'status': 'success',
            'archive_path': archive_path,
            'metadata': asdict(metadata)
        }
        
    async def diff(self, args: argparse.Namespace) -> Dict:
        """Execute diff command"""
        diff_engine = DiffEngine()
        
        # Handle relative dates
        archive1 = args.archive1
        archive2 = args.archive2
        
        if hasattr(args, 'yesterday') and args.yesterday:
            yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y%m%d')
            archive1 = f"/dataos-archives/{yesterday}"
            
        if hasattr(args, 'today') and args.today:
            today = datetime.now().strftime('%Y%m%d')
            archive2 = f"/dataos-archives/{today}"
            
        diff_result = await diff_engine.compute_diff(
            archive1,
            archive2,
            DiffMode(args.mode) if hasattr(args, 'mode') else DiffMode.BOTH
        )
        
        # Analyze changes
        analyzer = ChangeAnalyzer()
        analytics = analyzer.analyze(diff_result)
        
        # Send notification if significant changes
        if diff_result.total_changes > 0:
            await self.notification_service.notify('diff_complete', asdict(diff_result))
            
        return {
            'status': 'success',
            'diff_result': asdict(diff_result),
            'analytics': analytics
        }
        
    async def analyze(self, args: argparse.Namespace) -> Dict:
        """Execute analyze command"""
        # Load archive metadata
        metadata_path = os.path.join(args.archive, 'metadata.json')
        
        if not os.path.exists(metadata_path):
            raise FileNotFoundError(f"Archive metadata not found: {metadata_path}")
            
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
            
        # Generate analytics report
        analytics = {
            'archive': args.archive,
            'timestamp': datetime.now().isoformat(),
            'source_url': metadata['source_url'],
            'extraction_date': metadata['timestamp'],
            'statistics': {
                'total_pages': metadata['total_pages'],
                'extraction_time': metadata['extraction_time'],
                'format': metadata['format']
            },
            'content_analysis': self._analyze_content(args.archive)
        }
        
        # Save analytics
        analytics_path = os.path.join(args.archive, 'analytics.json')
        with open(analytics_path, 'w') as f:
            json.dump(analytics, f, indent=2)
            
        return {
            'status': 'success',
            'analytics': analytics,
            'report_path': analytics_path
        }
        
    def _analyze_content(self, archive_path: str) -> Dict:
        """Analyze content structure and statistics"""
        analysis = {
            'file_types': {},
            'total_size': 0,
            'largest_files': [],
            'content_structure': {}
        }
        
        for file_path in Path(archive_path).rglob('*'):
            if file_path.is_file():
                ext = file_path.suffix
                size = file_path.stat().st_size
                
                # Track file types
                if ext not in analysis['file_types']:
                    analysis['file_types'][ext] = {'count': 0, 'total_size': 0}
                analysis['file_types'][ext]['count'] += 1
                analysis['file_types'][ext]['total_size'] += size
                
                # Track total size
                analysis['total_size'] += size
                
                # Track largest files
                analysis['largest_files'].append({
                    'path': str(file_path.relative_to(archive_path)),
                    'size': size
                })
                
        # Sort largest files
        analysis['largest_files'].sort(key=lambda x: x['size'], reverse=True)
        analysis['largest_files'] = analysis['largest_files'][:10]
        
        return analysis
        
    async def schedule(self, args: argparse.Namespace) -> Dict:
        """Schedule regular extraction"""
        # Create schedule job
        def job():
            asyncio.run(self.extract(argparse.Namespace(
                source=args.source,
                format=args.format if hasattr(args, 'format') else 'markdown',
                method='hybrid'
            )))
            
        schedule.every().day.at(args.time if hasattr(args, 'time') else "02:00").do(job)
        
        if hasattr(args, 'cron') and args.cron:
            # Parse cron expression
            # For simplicity, using schedule library syntax
            if args.cron == "0 2 * * *":
                schedule.every().day.at("02:00").do(job)
            elif args.cron == "0 * * * *":
                schedule.every().hour.do(job)
            # Add more cron patterns as needed
            
        self.logger.info(f"Scheduled extraction for {args.source}")
        
        # In production, this would run as a daemon
        # For now, return success
        return {
            'status': 'success',
            'message': f'Extraction scheduled for {args.source}',
            'schedule': args.cron if hasattr(args, 'cron') else 'daily at 02:00'
        }

async def main():
    """CLI entry point"""
    parser = argparse.ArgumentParser(
        description='DataOS Documentation Extractor & Diff Engine'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # Extract command
    extract_parser = subparsers.add_parser('extract', help='Extract documentation')
    extract_parser.add_argument('--source', '-s', required=True, help='Source URL')
    extract_parser.add_argument('--format', '-f', default='markdown',
                              choices=['html', 'markdown', 'pdf', 'all'])
    extract_parser.add_argument('--method', '-m', default='hybrid',
                              choices=['static', 'dynamic', 'hybrid'])
    extract_parser.add_argument('--auth', '-a', help='Authentication JSON')
    extract_parser.add_argument('--output', '-o', help='Output directory')
    
    # Diff command
    diff_parser = subparsers.add_parser('diff', help='Compare archives')
    diff_parser.add_argument('--archive1', '-a1', help='First archive path')
    diff_parser.add_argument('--archive2', '-a2', help='Second archive path')
    diff_parser.add_argument('--yesterday', action='store_true', help='Use yesterday\'s archive')
    diff_parser.add_argument('--today', action='store_true', help='Use today\'s archive')
    diff_parser.add_argument('--mode', '-m', default='both',
                           choices=['semantic', 'visual', 'both', 'none'])
    
    # Analyze command
    analyze_parser = subparsers.add_parser('analyze', help='Analyze archive')
    analyze_parser.add_argument('--archive', '-a', required=True, help='Archive path')
    
    # Schedule command
    schedule_parser = subparsers.add_parser('schedule', help='Schedule extraction')
    schedule_parser.add_argument('--source', '-s', required=True, help='Source URL')
    schedule_parser.add_argument('--cron', '-c', help='Cron expression')
    schedule_parser.add_argument('--time', '-t', default='02:00', help='Time (HH:MM)')
    schedule_parser.add_argument('--format', '-f', default='markdown')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
        
    # Execute command
    extractor = DataOSDocsExtractor()
    
    try:
        if args.command == 'extract':
            result = await extractor.extract(args)
        elif args.command == 'diff':
            result = await extractor.diff(args)
        elif args.command == 'analyze':
            result = await extractor.analyze(args)
        elif args.command == 'schedule':
            result = await extractor.schedule(args)
        else:
            raise ValueError(f"Unknown command: {args.command}")
            
        # Pretty print result
        print(json.dumps(result, indent=2, default=str))
        
    except Exception as e:
        logger.error(f"Command failed: {e}", exc_info=True)
        print(json.dumps({
            'status': 'error',
            'message': str(e)
        }, indent=2))
        sys.exit(1)

if __name__ == '__main__':
    # Install playwright browsers if needed
    try:
        subprocess.run(['playwright', 'install', 'chromium'], check=True)
    except:
        pass
        
    # Run main
    asyncio.run(main())