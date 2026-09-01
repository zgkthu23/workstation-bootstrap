import unittest
from string_utils import StringUtils
class TestStringUtils(unittest.TestCase):
    
    def setUp(self):
        # 每个测试方法运行前执行，准备测试数据
        self.test_string = "Hello World"
    
    def test_reverse_string(self):
        # 测试字符串反转
        result = StringUtils.reverse_string(self.test_string)
        self.assertEqual(result, "dlroW olleH")
    
    def test_capitalize_words(self):
        # 测试单词大写
        result = StringUtils.capitalize_words("hello world")
        self.assertEqual(result, "Hello World")
    
    def test_count_vowels(self):
        # 测试元音字母计数
        result = StringUtils.count_vowels("Hello World")
        self.assertEqual(result, 3)  # e, o, o
    
    def test_reverse_empty_string(self):
        # 测试空字符串反转
        result = StringUtils.reverse_string("")
        self.assertEqual(result, "")

