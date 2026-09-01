# string_utils.py - 被测试的代码
class StringUtils:
    @staticmethod
    def reverse_string(s):
        return s[::-1]
    
    @staticmethod
    def capitalize_words(s):
        return ' '.join(word.capitalize() for word in s.split())
    
    @staticmethod
    def count_vowels(s):
        return sum(1 for char in s.lower() if char in 'aeiou')
